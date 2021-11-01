const {use, expect, util} = require('chai');
const {ContractFactory, utils, constants, BigNumber, ethers} = require('ethers');
const {waffleChai} = require('@ethereum-waffle/chai');
const {deployContract, deployMockContract, MockProvider} = require('ethereum-waffle');

const RevenueSharingPool = require('../build/RevenueSharingPool_Test');
const IPancakeRouter = require('../build/IPancakeRouter02.json');
const IWBNB = require('../build/IWBNB.json');
const ERC20 = require('../build/ERC20Token.json')

use(waffleChai);

describe('Revenue Sharing Pool', () => {
  async function setup() {
    const provider = new MockProvider();
    const [owner, account2, account3] = provider.getWallets();
    const lucky = await deployContract(owner, ERC20, [utils.parseEther('1000000')]);
    const busd = await deployContract(owner, ERC20, [utils.parseEther('1000000')]);
    const luckyBusd = await deployContract(owner, ERC20, [utils.parseEther('1000000')]);
    const router = await deployMockContract(owner, IPancakeRouter.abi);
    const wbnb = await deployMockContract(owner, IWBNB.abi);
    const contractFactory = new ContractFactory(RevenueSharingPool.abi, RevenueSharingPool.bytecode, owner);
    const revPool = await contractFactory.deploy(
      lucky.address, 
      luckyBusd.address, 
      owner.address, 
      router.address,
      busd.address,
      wbnb.address
    );
    return {owner, account2, account3, revPool, lucky, luckyBusd, provider};
  }

  // const preFundLPToken = async (address) => {
  //   const { luckyBusd } = await setup();
  //   await luckyBusd.transfer(address, 1000);
  // }

  const getDepositDate = async (numberOfdays) => {
    if (numberOfdays == 0) return 0;
    return (86400 * numberOfdays)
  }

  const getTimestamp = async () => {
    const { provider } = await setup();
    const blockNumber = await provider.getBlockNumber();
    const block = await provider.getBlock(blockNumber);
    const timestamp = block.timestamp;
    return timestamp;
  }

  it('Only owner of the contract can add whitelisted', async () => {
    const {revPool, account2} = await setup();
    await expect(revPool.connect(account2.address).addWhitelist(account2.address)).to.be.revertedWith("Ownable: caller is not the owner")
    expect(await revPool.addWhitelist(account2.address))
    expect(await revPool.whitelists(account2.address)).to.equal(true)
  });

  it('Only owner of the contract can remove whitelisted', async () => {
    const {revPool, account2} = await setup();
    await expect(revPool.connect(account2.address).removeWhitelist(account2.address)).to.be.revertedWith("Ownable: caller is not the owner")
    expect(await revPool.removeWhitelist(account2.address))
    expect(await revPool.whitelists(account2.address)).to.equal(false)
  });

  it('Only owner of the contract can update MAX DATE', async () => {
    const {revPool, account2} = await setup();
    await expect(revPool.connect(account2.address).updateMaxDate('14')).to.be.revertedWith("Ownable: caller is not the owner");
    expect(await revPool.updateMaxDate('14'));
    expect(await revPool.MAX_DATE()).to.equal('14')
  });

  it('Assigns initial LUCKY-BUSD balance', async () => {
    const {luckyBusd, owner} = await setup();
    expect(await luckyBusd.balanceOf(owner.address)).to.equal(utils.parseEther('1000000'));
    expect('balanceOf').to.be.calledOnContract(luckyBusd);
  });

  it('Can deposit LUCKY-BUSD', async () => {
    const {revPool, luckyBusd, owner} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);

    await expect(() => revPool.depositToken(100))
    .to.changeTokenBalances(luckyBusd, [owner, revPool], [-100, 100]);

    // const timestamp = await getTimestamp();
    // await expect(revPool.depositToken(100))
    // .to.emit(revPool, 'DepositStake')
    // .withArgs(owner.address, 100, timestamp);
  });

  it('If stake 0 LP will be reverted', async () => {
    const {revPool, luckyBusd} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);

    await expect(revPool.depositToken(0))
    .to.be.revertedWith('Insufficient deposit amount!');
  });

  it('Can withdraw LUCKY-BUSD', async () => {
    const {revPool, luckyBusd, owner, provider} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    await revPool.depositToken(100);

    await expect(() => revPool.withdrawToken())
    .to.changeTokenBalances(luckyBusd, [owner, revPool], [100, -100]);

    await revPool.depositToken(100);
    //const timestamp = await getTimestamp();
    // await expect(revPool.withdrawToken())
    // .to.emit(revPool, 'WithdrawStake')
    // .withArgs(owner.address, 100, timestamp);
  });

  it('User stake amount is updated', async () => {
    const {revPool, luckyBusd, owner} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);

    await revPool.depositToken(100);
    const userInfo = await revPool.userInfo(owner.address);
    expect(userInfo[0].toNumber()).to.equal(100);
  });

  it('User stake amount in current round must be updated', async () => {
    const {revPool, luckyBusd} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);

    await revPool.depositToken(100);
    const roundId = await revPool.getCurrentRoundId();
    const MAX_DATE = await revPool.MAX_DATE();
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.getStakeAmount(roundId, i)).to.equal(100);
    }
  });

  it('Total stake in current round must be updated', async () => {
    const {revPool, luckyBusd, account2} = await setup();
    const roundId = await revPool.getCurrentRoundId();
    const MAX_DATE = await revPool.MAX_DATE();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    await revPool.depositToken(100);
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.totalStake(roundId, i)).to.equal(100);
    }

    await luckyBusd.connect(account2).approve(revPool.address, constants.MaxUint256);
    await revPool.depositToken(100);
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.totalStake(roundId, i)).to.equal(200);
    }
  });

  it('Can withdraw LUCKY-BUSD', async () => {
    const {revPool, luckyBusd, owner} = await setup();

    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);

    await revPool.depositToken(100);
    await expect(() => revPool.withdrawToken())
    .to.changeTokenBalances(luckyBusd, [owner, revPool], [100, -100]);
  });

  it('If stake on day N stake amount must be updated from day N to MAX Day', async () => {
    const {revPool, luckyBusd, provider, account2, owner} = await setup();
    const roundId = await revPool.getCurrentRoundId();
    const MAX_DATE = await revPool.MAX_DATE();

    // Transfer LUCKY-BUSD to account2
    await expect(() => luckyBusd.transfer(account2.address, 100))
    .to.changeTokenBalances(luckyBusd, [owner, account2], [-100, 100]);

    // Deposit on first date
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);  
    await revPool.depositToken(100);

    for (let i = 1; i <= MAX_DATE; i++) { 
      const amount = await revPool.getStakeAmount(roundId, i)
      expect(amount.toNumber()).to.equal(100);
    }
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.totalStake(roundId, i)).to.equal(100);
    }

    // Increase date for testing
    const depositDate = await getDepositDate(2);
    await provider.send('evm_increaseTime', [depositDate]); 
    await provider.send('evm_mine');

    // Deposit on third date
    await luckyBusd.connect(account2).approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);  
    await revPool.connect(account2).depositToken(100);

    for (let i = 1; i <= MAX_DATE; i++) {
      const amount = await revPool.connect(account2).getStakeAmount(roundId, i)
      if (i > depositDate) {
        expect(amount.toNumber()).to.equal(100);
      }
    }

    for (let i = 1; i <= MAX_DATE; i++) {
      if (i > depositDate) {
        expect(await revPool.totalStake(roundId, i)).to.equal(200);
      }
    }
  });

  it('If user withdraw stake amount of current round must be removed', async () => {
    const { revPool, luckyBusd, owner } = await setup();
    const roundId = await revPool.getCurrentRoundId();
    const MAX_DATE = await revPool.MAX_DATE();

    // Deposit on first date
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);  
    await revPool.depositToken(100);

    for (let i = 1; i <= MAX_DATE; i++) { 
      const amount = await revPool.getStakeAmount(roundId, i)
      expect(amount.toNumber()).to.equal(100);
    }
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.totalStake(roundId, i)).to.equal(100);
    }

    // Withdraw all token
    await expect(() => revPool.withdrawToken())
    .to.changeTokenBalances(luckyBusd, [owner, revPool], [100, -100]);

    for (let i = 1; i <= MAX_DATE; i++) { 
      const amount = await revPool.getStakeAmount(roundId, i)
      expect(amount.toNumber()).to.equal(0);
    }
    for (let i = 1; i <= MAX_DATE; i++) {
      expect(await revPool.totalStake(roundId, i)).to.equal(0);
    }
  });

  it('Can deposit LUCKY revenue to contract', async () => {
    const { revPool, lucky, owner } = await setup();
    const roundId = await revPool.getCurrentRoundId();
    const winLoss = 100;
    const TPV = 50000;
    const percentOfRevshare = 9;
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  
    
    await revPool.addWhitelist(owner.address)

    await revPool.testDepositRevenue(100, winLoss, percentOfRevshare, TPV);
    
    // [Owner] update pool
    await revPool.updatePool();
    
    expect(await revPool.totalLuckyRevenue(roundId)).to.equal(100);
  });

  it('Can get history data of Revenue Sharing Pool on specific round', async () => {
    const { revPool, lucky, luckyBusd, owner } = await setup();
    
    // Initial variables
    const roundId = await revPool.getCurrentRoundId();
    const winLoss = 100;
    const TPV = 50000;
    const revenueAmount = 100
    const depositAmount = 500  
    const percentOfRevshare = 9;

    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);  
    
    // Deposit LUCKY-BUSD LP token
    await revPool.depositToken(depositAmount);

    // Approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);

    // Add whitelised address
    await revPool.addWhitelist(owner.address)

    // Deposit revenue
    await revPool.testDepositRevenue(revenueAmount, winLoss, percentOfRevshare, TPV);
    
    // Call poolInfo data
    const poolInfo = await revPool.poolInfo(roundId)
    expect(poolInfo[0]).to.equal(winLoss)
    expect(poolInfo[1]).to.equal(TPV)
    expect(poolInfo[2]).to.equal(revenueAmount)
    expect(poolInfo[3]).to.equal(depositAmount)
  });

  it('Can get pending LUCKY reward of specific round', async () => {
    const { revPool, lucky, luckyBusd, owner } = await setup();
    
    // Initial variables
    const roundId = await revPool.getCurrentRoundId();
    const winLoss = 100;
    const TPV = 50000;
    const revenueAmount = 100
    const depositAmount = 100
    const percentOfRevshare = 9
    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    // Deposit LUCKY-BUSD LP token
    await revPool.depositToken(depositAmount);

    // Approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  

    // Add whitelised address
    await revPool.addWhitelist(owner.address)

    // Deposit revenue
    await revPool.testDepositRevenue(revenueAmount, winLoss, percentOfRevshare, TPV);

    // [Owner] update pool
    await revPool.updatePool();
    
    // Call function getLuckyRewardPerRound
    const luckyReward = await revPool.getLuckyRewardPerRound(roundId)
    expect(luckyReward.toNumber()).to.lessThanOrEqual(revenueAmount)
  });

  it('Can claim pending reward of previous round', async () => {
    const { revPool, lucky, luckyBusd, owner, account2 } = await setup();
    
    // Initial variables
    const winLoss = 100;
    const TPV = 50000;
    const revenueAmount = 100
    const depositAmount = 100
    const percentOfRevshare = 9
    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    // Deposit LUCKY-BUSD LP token
    await revPool.depositToken(depositAmount);

    // Transfer LUCKY-BUSD to account2
    await expect(() => luckyBusd.transfer(account2.address, depositAmount))
    .to.changeTokenBalances(luckyBusd, [owner, account2], [-depositAmount, depositAmount]);

    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.connect(account2).approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
        
    // Deposit LUCKY-BUSD LP token
    await revPool.connect(account2).depositToken(depositAmount);

    // Approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  

    // Add whitelised address
    await revPool.addWhitelist(owner.address);

    // Deposit revenue
    await revPool.testDepositRevenue(revenueAmount, winLoss, percentOfRevshare, TPV);

    // [Owner] update pool
    await revPool.updatePool();
    
    // Get pending LUCKY reward
    const pendingReward = await revPool.getPendingReward();

    // Call claimReward function to claim pending LUCKY reward
    await expect(() => revPool.claimReward())
    .to.changeTokenBalances(lucky, [revPool, owner], [-pendingReward.toNumber(), pendingReward.toNumber()])
  });

  it('Can get pending LUCKY reward of specific round', async () => {
    const { revPool, lucky, luckyBusd, owner } = await setup();
    
    // Initial variables
    const roundId = await revPool.getCurrentRoundId();
    const winLoss = 100;
    const TPV = 50000;
    const revenueAmount = 100
    const depositAmount = 100
    const percentOfRevshare = 9
    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    // Deposit LUCKY-BUSD LP token
    await revPool.depositToken(depositAmount);

    // Approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  

    // Add whitelised address
    await revPool.addWhitelist(owner.address)

    // Deposit revenue
    await revPool.testDepositRevenue(revenueAmount, winLoss, percentOfRevshare, TPV);

    // [Owner] update pool
    await revPool.updatePool();
    
    // Call function getLuckyRewardPerRound
    const luckyReward = await revPool.getLuckyRewardPerRound(roundId)
    expect(luckyReward.toNumber()).to.lessThanOrEqual(revenueAmount)
  });

  it('Can claim pending reward of previous round', async () => {
    const { revPool, lucky, luckyBusd, owner, account2 } = await setup();
  
    // Initial variables
    const winLoss = 100;
    const TPV = 50000;
    const revenueAmount = 100
    const depositAmount = 100
    const percentOfRevshare = 5;
    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    // Deposit LUCKY-BUSD LP token
    await revPool.depositToken(depositAmount);

    // Transfer LUCKY-BUSD to account2
    await expect(() => luckyBusd.transfer(account2.address, depositAmount))
    .to.changeTokenBalances(luckyBusd, [owner, account2], [-depositAmount, depositAmount]);

    // Approve LUCKY-BUSD LP token to contract
    await luckyBusd.connect(account2).approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
        
    // Deposit LUCKY-BUSD LP token
    await revPool.connect(account2).depositToken(depositAmount);

    // Approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  

    // Add whitelised address
    await revPool.addWhitelist(owner.address);

    // Deposit revenue
    await revPool.testDepositRevenue(revenueAmount, winLoss, percentOfRevshare, TPV);

    // [Owner] update pool
    await revPool.updatePool();
    
    // Get pending LUCKY reward
    const pendingReward = await revPool.getPendingReward();

    // Call claimReward function to claim pending LUCKY reward
    await expect(() => revPool.claimReward())
    .to.changeTokenBalances(lucky, [revPool, owner], [-pendingReward.toNumber(), pendingReward.toNumber()])
  });

  it('All case (Deposit LP -> Withdraw -> Deposit Revenue -> Claim reward -> Get Pool history data)', async () => {
    const { revPool, lucky, luckyBusd, owner, account2, account3 } = await setup();
  
    //---------------------------------------Round 0---------------------------------------
    // Initial variables of round 0
    const data = {
      winLoss: 100,
      TPV: 50000,
      revenueAmount: utils.parseEther('100'),
      percentOfRevshare: 5,
      amount1: utils.parseEther('1'), // 25% shares
      amount2: utils.parseEther('1'), // 25% shares
      amount3: utils.parseEther('2') // 50% shares
    };
    
    // [Account1] approve LUCKY-BUSD LP token to contract
    await luckyBusd.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
    
    // [Account1] deposit LUCKY-BUSD LP token
    await revPool.depositToken(data.amount1);

    // [Account2] Pre-fund LP token
    await luckyBusd.transfer(account2.address, data.amount2);

    // [Account2] approve LUCKY-BUSD LP token to contract
    await luckyBusd.connect(account2).approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
        
    // [Account2] deposit LUCKY-BUSD LP token
    await revPool.connect(account2).depositToken(data.amount2);

    // [Account3] Pre-fund LP token
    await luckyBusd.transfer(account3.address, data.amount3);

    // [Account3] approve LUCKY-BUSD LP token to contract
    await luckyBusd.connect(account3).approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(luckyBusd, [revPool.address, constants.MaxUint256]);
            
    // [Account3] deposit LUCKY-BUSD LP token
    await revPool.connect(account3).depositToken(data.amount3);

    // [Owner] approve LUCKY to contract
    await lucky.approve(revPool.address, constants.MaxUint256);
    expect('approve').to.be.calledOnContractWith(lucky, [revPool.address, constants.MaxUint256]);  

    // [Owner] add whitelised address
    await revPool.addWhitelist(owner.address);

    // [Owner] deposit revenue
    await revPool.testDepositRevenue(data.revenueAmount, data.winLoss, data.percentOfRevshare, data.TPV);

    // [Owner] update pool
    await revPool.updatePool();
  
    // [Account1] Get pending LUCKY reward
    const pendingReward01 = await revPool.getPendingReward();

    // [Account1] Claim LUCKY reward
    await expect(() => revPool.claimReward())
    .to.changeTokenBalance(lucky, owner, pendingReward01.toString());
  
    // [Account2] Get pending LUCKY reward
    const pendingReward02 = await revPool.connect(account2).getPendingReward();

    // [Account2] Claim LUCKY reward
    await expect(() => revPool.connect(account2).claimReward())
    .to.changeTokenBalance(lucky, account2, pendingReward02.toString());
  
    // [Account3] Get pending LUCKY reward
    const pendingReward03 = await revPool.connect(account3).getPendingReward();

    // [Account3] Claim LUCKY reward
    await expect(() => revPool.connect(account3).claimReward())
    .to.changeTokenBalance(lucky, account3, pendingReward03.toString());

    //---------------------------------------Pool History of Round 0---------------------------------------
    const poolInfo = await revPool.poolInfo(0)
    expect(poolInfo[0]).to.equal(data.winLoss)
    expect(poolInfo[1]).to.equal(data.TPV)
    expect(poolInfo[2]).to.equal(data.revenueAmount)
    expect(poolInfo[3]).to.equal(await revPool.getLuckyBusdBalance())

  //---------------------------------------Round 1---------------------------------------
    // Initial variables of round 0
    const data2 = {
      winLoss: 50,
      TPV: 25000,
      revenueAmount: utils.parseEther('100'),
      percentOfRevshare: 5,
      amount1: utils.parseEther('1'),
      amount2: utils.parseEther('1'),
    };
    
    // [Account1] deposit LUCKY-BUSD LP token
    await revPool.depositToken(data2.amount1);

    // [Account2] Pre-fund LP token
    await luckyBusd.transfer(account2.address, data2.amount2);
        
    // [Account2] deposit LUCKY-BUSD LP token
    await revPool.connect(account2).depositToken(data2.amount2);

    // [Account3] withdraw LUCKY-BUSD LP token
    await revPool.connect(account3).withdrawToken();

    // [Owner] deposit revenue
    await revPool.testDepositRevenue(data2.revenueAmount, data2.winLoss,data2.percentOfRevshare, data2.TPV);

    // [Owner] update pool
    await revPool.updatePool();
  
    // [Account1] Get pending LUCKY reward
    const pendingReward11 = await revPool.getPendingReward();

    // [Account1] Claim LUCKY reward
    await expect(() => revPool.claimReward())
    .to.changeTokenBalance(lucky, owner, pendingReward11.toString());

    // [Account2] Get pending LUCKY reward
    const pendingReward12 = await revPool.connect(account2).getPendingReward();

    // [Account2] Claim LUCKY reward
    await expect(() => revPool.connect(account2).claimReward())
    .to.changeTokenBalance(lucky, account2, pendingReward12.toString());
  
    // [Account3] Get pending LUCKY reward
    // const pendingReward13 = await revPool.connect(account3).getPendingReward();

    // // [Account3] Claim LUCKY reward
    // await expect(() => revPool.connect(account3).claimReward())
    // .to.changeTokenBalance(lucky, account3, pendingReward13.toString());

    //---------------------------------------Pool History of Round 1---------------------------------------
    const poolInfo2 = await revPool.poolInfo(1)
    expect(poolInfo2[0]).to.equal(data2.winLoss)
    expect(poolInfo2[1]).to.equal(data2.TPV)
    expect(poolInfo2[2]).to.equal(data2.revenueAmount)
    expect(poolInfo2[3]).to.equal(await revPool.getLuckyBusdBalance())

  });
});