// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

// contract RevenueSharing is Ownable {
//     using SafeMath for uint256;
//     using SafeERC20 for IERC20;
//     address public luckyToken;

//     // day 0-6 (SUN-SAT) => totalStaked per day
//     mapping(uint256 => uint256) public totalStakedDays;

//     // day 0-6 (SUN-SAT) => totalStaked per day
//     mapping(uint256 => address) public userStakedDays;

//     // day 0-6 (SUN-SAT) => user address => staked amount
//     mapping(uint256 => mapping(address => uint256)) public userInfo;
//     address[] public users;

//     // user address => reward amount
//     mapping(address => uint256) public userRewards;

//     struct HistoryInfo {
//         string periodFrom;
//         string periodTo;
//         uint256 turnover;
//         uint256 revenue;
//     }

//     HistoryInfo[] public histories;

//     constructor(address _luckyToken) {
//         luckyToken = _luckyToken;
//     }

//     /// periodFrom and periodTo save into history
//     /// turnover from periodFrom - periodTo
//     /// revenue from periodFrom - periodTo
//     function shareRevenue(
//         string memory periodFrom,
//         string memory periodTo,
//         uint256 turnover,
//         uint256 revenue,
//         address[] calldata tokens,
//         uint256[] calldata amounts,
//         uint256 startBlock
//     ) public onlyOwner {
//         require(
//             tokens.length == amounts.length,
//             "shareRevenue: token? amount?"
//         );

//         uint256 totalLucky = 0;

//         for (uint8 i = 0; i < tokens.length; i++) {
//             require(amounts[i] > 0, "shareRevenue: need amount > 0");
//             if (tokens[i] != address(luckyToken)) {
//                 uint256 luckyFromSwapped = _swapToLucky(tokens[i], amounts[i]);
//                 totalLucky = totalLucky.add(luckyFromSwapped);
//             } else {
//                 totalLucky = totalLucky.add(amounts[i]);
//             }
//         }

//         require(totalLucky > 0, "shareRevenue: no lucky");

//         //

//         for (uint8 d = 0; d < 7; d++) {
//             uint256 totalStakedInDay = totalStakedDays[d];
//             // ได้ total staked รวมในแต่ละวัน

//             for (uint8 i = 0; i < userStakedDays.length; i++) {
//                 address userAddress = userStakedDays[i];
//                 uint256 staked = userInfo[d][userAddress];
//                 // ได้ user staked ในแต่ละวัน และ total staked รวมในแต่ละวัน จะรู้สัดส่วนของ user ในแต่ละวันได้
//                 // reward = สามารถหาส่วนแบ่ง reward ได้
//                 userRewards[userAddress] = reward;
//             }
//         }

//         histories.push(HistoryInfo(periodFrom, periodTo, turnover, revenue));
//     }

//     function _swapToLucky(address token, uint256 amount)
//         internal
//         returns (uint256)
//     {
//         // luckyFromSwapped = Call Pancakeswap router
//         // return luckyFromSwapped
//     }
// }
