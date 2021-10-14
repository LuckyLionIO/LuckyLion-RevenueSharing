//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./MasterPool.sol";
import "./tokens/LuckyToken.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IWETH.sol";


contract RevPool is Ownable {
    using SafeERC20 for IERC20;
    
    // The Lucky Token!
    LuckyToken public lucky;
    MasterPool public masterPool;
    IERC20 public BUSD;
    IWETH public wNative;
    IPancakeRouter02 public exchangeRouter;
    uint256 MAX;
    uint256 public totalLuckyRevenue;
    
    struct InputToken {
        address token;
        uint256 amount;
        address[] tokenToBUSDPath;
    }
    
    event DistributeLuckyRevenue(address from, address to, uint256 amounts);

    constructor (
        address owner_,
        MasterPool _masterPool,
        LuckyToken _lucky,
        IPancakeRouter02 _exchangeRouter,
        address _busd,
        address _wNative
    ) payable {
        masterPool = _masterPool;
        lucky = _lucky;
        exchangeRouter = IPancakeRouter02(_exchangeRouter);
        wNative = IWETH(_wNative);
        BUSD = IERC20(_busd);
        MAX = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        transferOwnership(owner_);
    }

    receive() external payable {}

    function shareRevenue(
        InputToken[] calldata inputTokens,
        address[] calldata BUSDToOutputPath,
        uint256 minOutputAmount
    ) external payable {
        
        uint256 luckyRevenue;
        
        address[] memory _path = new address[](2);
            _path[0] = address(wNative);
            _path[1] = address(BUSD);
        if (msg.value > 0) {
            wNative.deposit{value: msg.value}();
            uint256 wNativeBalance = wNative.balanceOf(address(this));
            _swapExactNativeForBUSD(wNativeBalance, _path);
        }
        
        if (inputTokens.length > 0 ) {
            for (uint256 i; i < inputTokens.length; i++) {
                if (inputTokens[i].token == address(lucky)) { //transfer LUCKY to Cave
                    IERC20(lucky).safeTransferFrom(msg.sender, address(this), inputTokens[i].amount);
                    totalLuckyRevenue += inputTokens[i].amount;
                    luckyRevenue += inputTokens[i].amount;
                } else if (inputTokens[i].token == address(BUSD)) { //transfer BUSD to Cave
                    IERC20(BUSD).safeTransferFrom(msg.sender, address(this), inputTokens[i].amount);
                } else {  //Swap Tokens for BUSD
                    _transferTokensToCave(inputTokens[i]);
                    _swapTokensForBUSD(inputTokens[i]);
                }
            }
        }
        
        uint256 BUSDBalance = BUSD.balanceOf(address(this));
        uint256 amountOut = _swapBUSDForToken( //Swap BUSD for LUCKY
            BUSDBalance,
            BUSDToOutputPath
        );
        
        require(
            amountOut >= minOutputAmount,
            "Expect amountOut to be greater than minOutputAmount."
        );
        
        totalLuckyRevenue += amountOut;
        luckyRevenue += amountOut;
        
        emit DistributeLuckyRevenue(msg.sender, address(this), luckyRevenue);
    }
    
    // Safe reward transfer function for user to withdraw their reward from this contract.
    function claimReward(address _to, uint256 _amount) external {
        //uint256 rewardBal = masterPool.balanceOf(address(this));
        // if (_amount > luckyBal) {
        //     lucky.transfer(_to, luckyBal);
        // } else {
        //     lucky.transfer(_to, _amount);
        // }
        lucky.transfer(_to, _amount); // need to checking balance logic.
    }
    
    function _transferTokensToCave(InputToken calldata inputTokens) private {
            IERC20(inputTokens.token).safeTransferFrom(
                msg.sender,
                address(this),
                inputTokens.amount
            );
    }
    
    function _swapExactNativeForBUSD(uint256 amount, address[] memory path) private returns (uint256){
        if (amount == 0 || path[path.length - 1] == address(wNative)) {
            return amount;
        }
        wNative.approve(address(exchangeRouter), MAX);
        exchangeRouter.swapExactTokensForTokens(
            amount,
            0,//minimum amount out can optimize by cal slippage
            path,
            address(this),
            block.timestamp + 60
        );
    }
    
    function _swapTokensForBUSD(InputToken calldata inputTokens) private {
        if (inputTokens.token != address(BUSD)) {
            IERC20(inputTokens.token).approve(address(exchangeRouter), MAX);
            exchangeRouter.swapExactTokensForTokens(
                inputTokens.amount,
                0, //minimum amount out can optimize by cal slippage
                inputTokens.tokenToBUSDPath,
                address(this),
                block.timestamp + 60
            );
        }
    }

    function _swapBUSDForToken(uint256 amount, address[] memory path)
        private
        returns (uint256)
    {
        if (amount == 0 || path[path.length - 1] == address(BUSD)) {
            return amount;
        }
        BUSD.approve(address(exchangeRouter), MAX);
        uint256[] memory amountOuts = exchangeRouter.swapExactTokensForTokens(
            amount,
            0,//minimum amount out can optimize by cal slippage
            path,
            address(this),
            block.timestamp + 60
        );
        return amountOuts[amountOuts.length - 1];
    }
}