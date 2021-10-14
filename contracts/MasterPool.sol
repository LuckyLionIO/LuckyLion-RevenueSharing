pragma solidity 0.8.7; //SPDX-License-Identifier: UNLICENSED

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MasterPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    uint256 START_DATE;
    
    // // day 1-7 (SUN-SAT) => totalStaked per day
    // mapping(uint256 => uint256) public totalStakedDays;

    // // day 1-7 (SUN-SAT) => user address => staked amount
    // mapping(uint256 => mapping(address => uint256)) public userInfo;
    
    mapping(address => uint256) stakeAmount;
    
    //declare the luckyBusd instance here
    IERC20 public luckyBusd;
    
    //total LP in Pool
    uint256 totalStake;

    event Deposit(address indexed user, uint256 amount, uint256 depositDate);
    event Withdraw(address indexed user, uint256 amount, uint256 depositDate);

    constructor(IERC20 _luckyBusd, uint256 _startDate) {
        luckyBusd = _luckyBusd;
        START_DATE = _startDate;
    }
    
    function getTotalStake() external view returns (uint256) {
        return totalStake;
    }
    
    function getStakeAmount() external view returns (uint256) {
        return stakeAmount[msg.sender];
    }

    // Deposit LP tokens to MasterPool for lucky allocation.
    function deposit(uint256 _amount) external nonReentrant {
        if (_amount > 0) {
            luckyBusd.safeTransferFrom(address(msg.sender), address(this), _amount);
            stakeAmount[msg.sender] += _amount;
            totalStake += _amount;
        }
        emit Deposit(msg.sender, _amount, block.timestamp);
    }
    
    // Withdraw LP tokens from MasterPool.
    function withdraw() external nonReentrant {
        uint256 amount = stakeAmount[msg.sender];
        luckyBusd.safeTransfer(address(msg.sender), amount);
        stakeAmount[msg.sender] = 0;
        totalStake -= amount;
        emit Withdraw(msg.sender, amount, block.timestamp);
    }
}