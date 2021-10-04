pragma solidity 0.8.7; //"SPDX-License-Identifier: UNLICENSED"

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./MasterPool.sol";
import "./LuckyToken.sol";
import "./libs/IPancakeRouter02.sol";


contract RevPool is ERC20('RevPool', 'RevPool'), Ownable {
    using SafeERC20 for IERC20;

    struct SlotInfo {
                uint256 priorLucky;
                uint256 priorBalance;
                uint256 totalLucky;
                uint256 swappedAmount;
                }
    SlotInfo private slotInfo;
    // The Lucky Token!
    LuckyToken public lucky;
    
    MasterPool public masterPool;
    
    IPancakeRouter02 public swapRouter;

    IERC20 public busd;
    uint16 public slippageFactor;
 
    //uint256 public swapDeadlineInterval;
    constructor(
        address owner_,
        MasterPool _masterPool,
        LuckyToken _lucky,
        //IERC20 _busd,
        IPancakeRouter02 _swapRouter
    ) {
        masterPool = _masterPool;
        transferOwnership(owner_);
        lucky = _lucky;
        //busd = _busd;
        swapRouter = _swapRouter;
        slippageFactor = 1015;
    }

    // Safe reward transfer function for user to withdraw their reward from this contract.
    function safeRewardTransfer(address _to, uint256 _amount) external onlyOwner {
        //uint256 rewardBal = masterPool.balanceOf(address(this));
        // if (_amount > luckyBal) {
        //     lucky.transfer(_to, luckyBal);
        // } else {
        //     lucky.transfer(_to, _amount);
        // }
        lucky.transfer(_to, _amount); // need to checking balance logic.
    }

    function depositRewardAndSwap
        (address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata path0,
        address[] calldata path1,
        uint256 swapDeadlineInterval) public onlyOwner{
            require(tokens.length == amounts.length,
            "revPool.sol:depositRewardAndSwap: tokens length must be equal amounts length"
            );
            //conditions
            //1.amount of path array = tokens.length
            //2.final index of path has to be lucky
            //3.path length must be equl or more than 2.
            // uint8 countTokens;
            // bool countLucky;
            // if (tokens[0] ==address(lucky)){
            //     require(path0[0]=address(lucky),"revPool.sol:depositRewardAndSwap, must be sole Lucky");
            //     countLucky +=1;
            //     countLucky =true
            // }
            // else if (path0.length >= 2) { 
            //     countTokens += 1;
            //     require(path0[path0.length - 1]=address(lucky),"revPool.sol:depositRewardAndSwap, the last token in path must be Lucky");
            // }
            // if (path1.length ==1){
            //     require(path1[0]=address(lucky),"revPool.sol:depositRewardAndSwap, must be sole Lucky");
            //     countLucky += 1;
            // }
            // else if (path1.length >= 2) {
            //     countTokens += 1;
            //     require(path1[path1.length - 1]=address(lucky),"revPool.sol:depositRewardAndSwap, the last token in path must be Lucky");
            // }
            // if (path2.length ==1){
            //     require(path2[0]=address(lucky),"revPool.sol:depositRewardAndSwap, must be sole Lucky");
            //     countLucky += 1;
            // }
            // else if (path2.length >= 2) {
            //     countTokens += 1;
            //     require(path2[path2.length - 1]=address(lucky),"revPool.sol:depositRewardAndSwap, the last token in path must be Lucky");
            // }
            // require(countTokens=(tokens.length-countLucky),"RevPool.sol:depositRewardAndSwap: must specify all paths for all tokens");
            
            //uint256 totalLucky = 0;
            
            slotInfo.priorLucky = lucky.balanceOf(address(this));

            for (uint8 i = 0; i < tokens.length; i++) {
                require(amounts[i] > 0, "RevPool.sol:depositRewardAndSwap:: need amount > 0");
                if (tokens[i] != address(lucky) /*&& tokens[i] != address(busd)*/) {
                    if (path0[0]==tokens[i]){
                        require( path1[0]!=tokens[i] && path0[path0.length-1]==address(lucky),"RevPool.sol:depositRewardAndSwap:: beginning and the end of the path must be correct");
                        //swap usdt to busd then busd to lucky
                        slotInfo.priorBalance = lucky.balanceOf(msg.sender);
                        IERC20(tokens[i]).safeApprove(address(swapRouter),amounts[i]);
                        _safeSwap(
                                address(swapRouter),
                                amounts[i],
                                slippageFactor,
                                path0,
                                msg.sender,
                                block.timestamp + swapDeadlineInterval
                            );
                        slotInfo.swappedAmount = lucky.balanceOf(msg.sender) -slotInfo.priorBalance;
                        IERC20(tokens[i]).safeTransferFrom(msg.sender,address(this),slotInfo.swappedAmount);
                        delete slotInfo;
                    }
                    else{
                        require( path0[0]!=tokens[i] && path1[path1.length-1]==address(lucky),"RevPool.sol:depositRewardAndSwap:: beginning and the end of the path must be correct");
                        //swap usdt to busd then busd to lucky
                        slotInfo.priorBalance = lucky.balanceOf(msg.sender);
                        IERC20(tokens[i]).safeApprove(address(swapRouter),amounts[i]);
                        _safeSwap(
                                address(swapRouter),
                                amounts[i],
                                slippageFactor,
                                path1,
                                msg.sender,
                                block.timestamp + swapDeadlineInterval
                            );
                        slotInfo.swappedAmount = lucky.balanceOf(msg.sender) -slotInfo.priorBalance;
                        IERC20(tokens[i]).safeTransferFrom(msg.sender,address(this),slotInfo.swappedAmount);
                        delete slotInfo;
                    }
                }
                else {
                    IERC20(tokens[i]).safeTransferFrom(msg.sender,address(this),amounts[i]);
                }
                
                slotInfo.totalLucky = lucky.balanceOf(address(this)) - slotInfo.priorLucky;
                //.... some code here.
                
                delete slotInfo;
                    
                    // uint256 luckyFromSwapped = _swapToLucky(tokens[i], amounts[i]);
                    // totalLucky = totalLucky.add(luckyFromSwapped);
                // } else {
                //     totalLucky = totalLucky.add(amounts[i]);
                // }
            }

            // require(totalLucky > 0, "shareRevenue: no lucky");
    
        }
    
    function _swapToLucky(address token, uint256 amount)
        internal
        returns (uint256)
    {
        // luckyFromSwapped = Call Pancakeswap router
        // return luckyFromSwapped
    }

    
    function _safeSwap(
        address _RouterAddress,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal virtual {
        uint256[] memory amounts =
            IPancakeRouter02(_RouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length - 1];

        IPancakeRouter02(_RouterAddress)
            .swapExactTokensForTokens(
            _amountIn,
            amountOut *_slippageFactor /1000, //slippage factor has 1 decimal. like 1.5% >>_slippageFactor =1015 
            _path,
            _to,
            _deadline
        );

        
    }
}