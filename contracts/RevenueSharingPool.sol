// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './utils/Counters.sol';

contract RevenueSharingPool is Ownable {
    // Utility Libraries  
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _roundId;

    // swap token related variables
    IERC20 public luckyBusd;
    
    // contract global variables
    uint256 public START_ROUND_DATE;
    mapping(uint256 => uint256) public MAX_DATE;
    uint256 public numberOfDate;
    
    // staking related variables
    mapping(uint256 => mapping(uint256 => uint256)) public totalStake;
    mapping(uint256 => uint256) public totalLuckyRevenue;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public stakeAmount;
    address[] internal stakeholders;
    mapping(address => bool) public whitelists;
    
    // user info variables
    struct UserInfo {
        uint256 amount;
        uint256 rewardDept;
        uint256 pendingReward;
        uint256 lastUpdateRoundId;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // pool info
    struct PoolInfo {
	    uint256 winLoss;
	    uint256 TPV;
	    string symbol;
	    uint256 TVL;
	    uint256 percentOfRevshare;
	    uint256 participants;
	    uint256 totalLuckyRevenue;
    }
    
    mapping(uint256 => PoolInfo) public poolInfo;

    event DepositStake(address indexed account, uint256 amount, uint256 timestamp);
    event WithdrawStake(address indexed account, uint256 amount, uint256 timestamp);
    event ClaimReward(address indexed account, uint256 amount, uint256 timestamp);
    event DistributeLuckyRevenue(address from, address to, uint256 amounts);
    event UpdateMaxDate(uint256 newMaxDate);
    event AddWhitelist(address indexed account);
    event RemoveWhitelist(address indexed account);
    
    modifier isWhitelisted(address addr) {
        require(whitelists[addr], "Permission Denied");
        _;
    }

    constructor (
        address _luckyBusd,
        address owner_
    ){
        luckyBusd = IERC20(_luckyBusd);
        START_ROUND_DATE = block.timestamp;        
        transferOwnership(owner_);
        numberOfDate = 7;
        MAX_DATE[0] = numberOfDate;
    }
    
    //-------------------------Staking Functions -------------------------//
    
    // deposit LUCKY-BUSD LP token
    function depositToken(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(amount > 0, "Insufficient deposit amount!");
        luckyBusd.safeTransferFrom(msg.sender, address(this), amount);
        uint256 depositDate = getDepositDate();
        uint256 roundId = getCurrentRoundId();
        
        addStakeholder(msg.sender);
        
        if (!isStakeUpToDate(roundId)) {
           updatePendingStake(); 
        }
        
        user.amount += amount;
        updateStake(roundId, depositDate, amount);
        emit DepositStake(msg.sender, amount, block.timestamp);
    }
    
    // withdraw LUCKY-BUSD LP token
    function withdrawToken() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 roundId = getCurrentRoundId();

        if (!isStakeUpToDate(roundId)) {
           updatePendingStake(); 
        }
        
        updatePendingReward();
        uint256 amount = user.amount;
        user.amount = 0;
        removeStake(roundId);
        removeStakeholder(msg.sender);
        luckyBusd.safeTransfer(msg.sender, amount);
        emit WithdrawStake(msg.sender, amount, block.timestamp);
    }
    
    // emergency withdraw LUCKY-BUSD LP token without calculated pending reward (just withdraw LP)
    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 roundId = getCurrentRoundId();
        uint256 amount = user.amount;
        user.amount = 0;
        user.lastUpdateRoundId = roundId;
        removeStake(roundId);
        removeStakeholder(msg.sender);
        luckyBusd.safeTransfer(msg.sender, amount);
        emit WithdrawStake(msg.sender, amount, block.timestamp);
    }
    
    // claim LUCKY reward
    function claimReward() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 roundId = getCurrentRoundId();
        
        if (user.amount > 0) {
            if (!isStakeUpToDate(roundId)) {
               updatePendingStake(); 
            }
            updatePendingReward();
        }
        
        uint256 claimableLuckyReward = user.pendingReward;
        require(claimableLuckyReward > 0, "Not enough claimable LUCKY reward!");
        user.rewardDept += claimableLuckyReward;
        user.pendingReward -= claimableLuckyReward;
        emit ClaimReward(msg.sender, claimableLuckyReward, block.timestamp);
    }
    
    //-------------------------Updater Functions -------------------------//
    
   function addStakeholder(address account) internal {
       (bool _isStakeholder, ) = isStakeholder(account);
       if (!_isStakeholder) stakeholders.push(account);
   }

   function removeStakeholder(address account) internal {
       (bool _isStakeholder, uint256 i) = isStakeholder(account);
       if (_isStakeholder){
           stakeholders[i] = stakeholders[stakeholders.length - 1];
           stakeholders.pop();
       }
    }
    
    function updateRoundId() internal {
        _roundId.increment(); // increase round id when owner deposit revenue share to the contract
    }
    
    // Update max number of day in a round (default 7 days)
    function updateMaxDate(uint256 newMaxDate) external onlyOwner {
        uint256 currentRoundId = getCurrentRoundId();
        numberOfDate = newMaxDate;
        MAX_DATE[currentRoundId] = numberOfDate;
        emit UpdateMaxDate(newMaxDate);
    }
    
    function addWhitelist(address addr) external onlyOwner {
        whitelists[addr] = true;
        emit AddWhitelist(addr);
    }

    function removeWhitelist(address addr) external onlyOwner {
        whitelists[addr] = false;
        emit RemoveWhitelist(addr);
    }
    
    function updatePoolInfo(uint256 winLoss, uint256 TPV, string memory symbol, uint256 revenueAmount, uint256 percentOfRevshare, uint256 roundID) internal {
	    uint256 totalValueLock = luckyBusd.balanceOf(address(this));
	    PoolInfo storage _poolInfo = poolInfo[roundID];
	    _poolInfo.winLoss = winLoss;
	    _poolInfo.TPV = TPV;
        _poolInfo.symbol = symbol;
        _poolInfo.percentOfRevshare = percentOfRevshare;
	    _poolInfo.TVL = totalValueLock;
	    _poolInfo.participants = stakeholders.length;
	    _poolInfo.totalLuckyRevenue = revenueAmount;
    }

    function removeStake(uint256 roundId) internal {
        for (uint256 i = 1; i <= MAX_DATE[roundId]; i++) {
            uint256 amount = stakeAmount[roundId][i][msg.sender];
            stakeAmount[roundId][i][msg.sender] -= amount;
            totalStake[roundId][i] -= amount;
        }
    }
    
    function updateStake(uint256 roundId, uint256 depositDate, uint256 amount) internal {
        for(uint256 i = depositDate; i <= MAX_DATE[roundId]; i++) {
            stakeAmount[roundId][i][msg.sender] += amount;
            totalStake[roundId][i] += amount;
        }
    }
    
    // Update pending stake of msg.sender from last update round to current round (MasterPool)
    function updatePendingStake() internal {
        UserInfo storage user = userInfo[msg.sender];
        uint256 lastUpdateRoundId = user.lastUpdateRoundId;
        uint256 currentRoundId = getCurrentRoundId();
        uint256 amount = user.amount;
        // If last update stake amount is on round 2 so we need to update stake amount from round 3 - 5
        for(uint256 i = (lastUpdateRoundId + 1); i <= currentRoundId; i++) {
            for(uint256 j = 1; j <= MAX_DATE[currentRoundId]; j++) {
                stakeAmount[i][j][msg.sender] = amount;
            }
        }
        user.lastUpdateRoundId = currentRoundId;
    }
    
    function updateTotalStake(uint256 roundId) internal {
        uint256 _totalStake = luckyBusd.balanceOf(address(this));
        for(uint256 i = 1; i <= MAX_DATE[roundId]; i++) {
            totalStake[roundId][i] = _totalStake;
        }
    }
    
    function updatePendingReward() internal {
        UserInfo storage user = userInfo[msg.sender];
        uint256 luckyReward = calculateTotalLuckyReward(msg.sender);
        uint256 luckyRewardDept = user.rewardDept;
        user.pendingReward = (luckyReward - luckyRewardDept);
    }
    
    function calculateLuckyReward(address account, uint256 roundId) internal view returns (uint256) {
        uint256 luckyReward;
        uint256 totalLuckyRevenuePerDay = getTotalLuckyRewardPerDay(roundId);
        if (totalLuckyRevenuePerDay == 0) {
            return 0;
        }
        for (uint256 i = 1; i <= MAX_DATE[roundId]; i++) {
            uint256 amount = stakeAmount[roundId][i][account];
            if (amount == 0) continue;
            uint256 _totalStake = totalStake[roundId][i];
            uint256 userSharesPerDay = (amount * 1e18) / _totalStake;
            luckyReward += (totalLuckyRevenuePerDay * userSharesPerDay) / 1e18;
        }
        return luckyReward;
    }
    
    function calculateTotalLuckyReward(address _address) internal view returns (uint256) {
        uint256 totalLuckyReward = 0;
        uint256 roundId = getCurrentRoundId();
        for (uint256 i = 0; i < roundId; i++) { 
            totalLuckyReward += calculateLuckyReward(_address, i);
        }
        return totalLuckyReward;
    }
    
    //-------------------------Getter Functions -------------------------//
    
   function isStakeholder(address _address) public view returns(bool, uint256) {
       for (uint256 s = 0; s < stakeholders.length; s += 1){
           if (_address == stakeholders[s]) return (true, s);
       }
       return (false, 0);
    }
   
    // return current round id
    function getCurrentRoundId() public view returns (uint256) {
        return _roundId.current();
    }
    
    // return user stake amount of specific round and date
    function getStakeAmount(uint256 roundId, uint256 day, address _address) external view returns (uint256) {
        return stakeAmount[roundId][day][_address];
    }
     
    // Get past time (in seconds) since start round
    function getRoundPastTime() external view returns (uint256) {
        return (block.timestamp - START_ROUND_DATE);
    }
    
    // check deposit date of msg.sender (date range: 1 - MAX_DATE)
    function getDepositDate() internal view returns (uint256) {
        uint256 roundId = getCurrentRoundId();
        for (uint256 i = 1; i <= MAX_DATE[roundId]; i++) { 
            if (block.timestamp >= START_ROUND_DATE && block.timestamp < START_ROUND_DATE + (i * 1 days)) { 
                return i;
            }
        }
        return 0;
    }
    
    // return total LUCKY reward per day of specific round
    function getTotalLuckyRewardPerDay(uint256 roundId) public view returns (uint256) {
        return (totalLuckyRevenue[roundId] / MAX_DATE[roundId]);
    }
    
    // return total LUCKY-BUSD LP balance in this contract
    function getLuckyBusdBalance() external view returns (uint256) {
        return luckyBusd.balanceOf(address(this));
    }
     
    // return unclaimed LUCKY reward of msg.sender
    function getPendingReward(address _address) external view returns (uint256) {
        UserInfo storage user = userInfo[_address];
        if (user.amount == 0) {
            return user.pendingReward;
        }
        uint256 luckyReward = calculateTotalLuckyReward(_address);
        uint256 luckyRewardDept = user.rewardDept;
        return (luckyReward - luckyRewardDept);
    }
    
    function getLuckyRewardPerRound(uint256 roundId, address _address) external view returns (uint256){
	    uint256 luckyReward = calculateLuckyReward(_address, roundId);
	    return luckyReward;
    }
    
    // checking whether user reward is up-to-date or not
    function isStakeUpToDate(uint256 currentRoundId) internal view returns (bool) {
        return (userInfo[msg.sender].lastUpdateRoundId == currentRoundId);
    }
    
    //-------------------------Deposit Revenue Functions -------------------------//
    
    // for owner to deposit revenue (any tokens) to RevenueSharingPool contract
    function depositRevenue(
        string memory symbol,
        uint256 amount,
        uint256 winLoss,
        uint256 TPV,
        uint256 percentOfRevshare
    ) external isWhitelisted(msg.sender) {
        uint256 roundId = getCurrentRoundId();
        totalLuckyRevenue[roundId] += amount;
        updatePoolInfo(winLoss, TPV, symbol, amount, percentOfRevshare, roundId); // update round pool info
        START_ROUND_DATE = block.timestamp;
        updateRoundId();
        uint256 currentRoundId = getCurrentRoundId();
        MAX_DATE[currentRoundId] = numberOfDate;
        updateTotalStake(currentRoundId); // update new round total stake
        emit DistributeLuckyRevenue(msg.sender, address(this), amount);
    }
}
