// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPaymentToken is IERC20 {
    function burnFrom(address account, uint256 value) external;
}

interface IOracle {
    function getTokenPriceInUSD(uint32 secondsAgo, address token) external view returns (uint256);
}

enum PayType {
    None,
    FixedCount,
    Monthly
}

struct VIPDetail {
    PayType tp;
    uint256 startAt;
    uint256 endAt;
    uint256 totalQuotas;
    uint256 usedQuotas;
}
