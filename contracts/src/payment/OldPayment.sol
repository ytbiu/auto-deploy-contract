// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Types.sol";

/// @title Payment Contract for VIP Service Management
/// @notice This contract manages VIP subscriptions with two payment models:
/// 1. Monthly subscription with time-based quotas
/// 2. Fixed-count subscription with usage-based quotas
/// @custom:oz-upgrades-from OldPayment
contract OldPayment is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Number of decimals used for USD amounts
    uint256 constant USD_DECIMALS = 6;
    /// @notice Token used for payments
    IPaymentToken public paymentToken;

    IERC20 public usdt;
    /// @notice Oracle contract for token price conversion
    IOracle public oracle;
    uint256 public freeRequestCount;
    uint256 public addressFreeRequestCount;
    uint256 public minUSDBalanceForUsingFreeRequest;
    /// @notice Monthly VIP subscription price in USD (with decimals)
    uint256 public vipPriceMonthly;
    /// @notice Fixed-count VIP subscription price in USD (with decimals)
    uint256 public vipPriceFixedCount;
    uint256 public minVIPFixCountToPay;

    /// @notice Number of quotas granted for monthly VIP subscription
    uint256 public vipMonthlyQuotas;

    mapping(address => uint256) public address2FreeRequestCount;
    /// @notice Mapping from user address to their VIP subscription details
    mapping(address => VIPDetail) public address2VIPDetail;
    /// @notice Total amount of payment tokens burned
    uint256 public totalBurned;

    /// @notice Emitted when a user purchases VIP subscription
    event buyVIP(address indexed user, uint256 burnPaymentAmount, PayType tp);
    /// @notice Emitted when a user requests to use VIP quotas
    event requestVIP(address indexed user, uint256 quotas);
    event requestFree(address indexed user, uint256 userFreeQuotas, uint256 globalReeQuotas);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with owner and payment token
    /// @param owner Address of the contract owner
    /// @param _paymentToken Address of the payment token contract
    function initialize(
        address owner,
        address _paymentToken,
        uint256 _freeRequestCount,
        uint256 _addressFreeRequestCount,
        uint256 _minUSDBalanceInUSDForUsingFreeRequest,
        uint256 _vipMonthlyQuotas,
        uint256 _vipPriceFixedCount,
        uint256 _vipPriceMonthly
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(owner);

        paymentToken = IPaymentToken(_paymentToken);

        //        usdt = IERC20(0x5155101187F8Faa1aD8AfeC7820c801870F81D52);
        usdt = IERC20(0x91635139C096e04206F22471F06CD10675bF9981);
        freeRequestCount = _freeRequestCount;
        addressFreeRequestCount = _addressFreeRequestCount;
        minUSDBalanceForUsingFreeRequest = _minUSDBalanceInUSDForUsingFreeRequest;
        vipMonthlyQuotas = _vipMonthlyQuotas;
        vipPriceFixedCount = _vipPriceFixedCount;
        vipPriceMonthly = _vipPriceMonthly;
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    /// @notice Sets the oracle contract address
    /// @param addr Address of the oracle contract
    function setOracle(address addr) external onlyOwner {
        oracle = IOracle(addr);
    }

    function setConfig(
        uint256 _vipMonthlyQuotas,
        uint256 _vipPriceMonthly,
        uint256 _vipPriceFixedCount,
        uint256 _minVIPFixCountToPay
    ) external onlyOwner {
        vipMonthlyQuotas = _vipMonthlyQuotas;
        vipPriceMonthly = _vipPriceMonthly;
        vipPriceFixedCount = _vipPriceFixedCount;
        minVIPFixCountToPay = _minVIPFixCountToPay;
    }

    /// @notice Sets the payment token contract address
    /// @param _token Address of the payment token contract
    function setPaymentToken(address _token) external onlyOwner {
        paymentToken = IPaymentToken(_token);
    }

    function tryUseFreeRequest() internal returns (bool) {
        if (usdt.balanceOf(msg.sender) < minUSDBalanceForUsingFreeRequest && freeRequestCount == 0) {
            return false;
        }

        if (address2FreeRequestCount[msg.sender] > 0) {
            address2FreeRequestCount[msg.sender] -= 1;
        }

        if (freeRequestCount > 0) {
            freeRequestCount -= 1;
        }
        emit requestFree(msg.sender, address2FreeRequestCount[msg.sender], freeRequestCount);
        return true;
    }

    /// @notice Purchases monthly VIP subscription
    /// @param _monthCount Number of months to subscribe
    function payForMonthlyVIP(uint256 _monthCount) external {
        require(canPayVIP(msg.sender, PayType.Monthly), "has vip in use");
        uint256 tokenAmount = monthlyVIPAmountPay(_monthCount);
        paymentToken.burnFrom(msg.sender, tokenAmount);
        totalBurned += tokenAmount;
        VIPDetail memory existVIPDetail = address2VIPDetail[msg.sender];
        uint256 _totalQuotas = vipMonthlyQuotas * _monthCount;
        uint256 _usedQuotas = 0;
        uint256 _startAt = block.timestamp;
        uint256 _endAt = block.timestamp + 30 days * _monthCount;
        if (existVIPDetail.tp == PayType.Monthly && block.timestamp < existVIPDetail.endAt) {
            _totalQuotas += existVIPDetail.totalQuotas;
            _usedQuotas = existVIPDetail.usedQuotas;
            _startAt = existVIPDetail.startAt;
            _endAt = existVIPDetail.endAt + 30 days * _monthCount;
        }
        address2VIPDetail[msg.sender] = VIPDetail({
            tp: PayType.Monthly,
            totalQuotas: _totalQuotas,
            usedQuotas: _usedQuotas,
            startAt: _startAt,
            endAt: _endAt
        });

        emit buyVIP(msg.sender, tokenAmount, PayType.Monthly);
    }

    /// @notice Purchases fixed-count VIP subscription
    /// @param _fixedCount Number of quotas to purchase
    function payForFixedCountVIP(uint256 _fixedCount) external {
        require(_fixedCount > minVIPFixCountToPay, "fixed count should be greater than min count");
        require(canPayVIP(msg.sender, PayType.FixedCount), "has vip in use");
        uint256 tokenAmount = fixedCountVIPAmountPay(_fixedCount);
        paymentToken.burnFrom(msg.sender, tokenAmount);
        totalBurned += tokenAmount;
        VIPDetail memory existVIPDetail = address2VIPDetail[msg.sender];
        uint256 _totalQuotas = _fixedCount;
        uint256 _usedQuotas = 0;
        uint256 _startAt = block.timestamp;
        if (existVIPDetail.tp == PayType.FixedCount && existVIPDetail.totalQuotas > existVIPDetail.usedQuotas) {
            _totalQuotas += existVIPDetail.totalQuotas;
            _usedQuotas = existVIPDetail.usedQuotas;
            _startAt = existVIPDetail.startAt;
        }

        address2VIPDetail[msg.sender] = VIPDetail({
            tp: PayType.FixedCount,
            totalQuotas: _totalQuotas,
            usedQuotas: _usedQuotas,
            startAt: _startAt,
            endAt: 0
        });
        emit buyVIP(msg.sender, tokenAmount, PayType.FixedCount);
    }

    /// @notice Calculates token amount needed for USD amount
    /// @param usdWithDecimals USD amount with decimals
    /// @return Token amount needed
    function tokenAmountInUSD(uint256 usdWithDecimals) public view returns (uint256) {
        return usdWithDecimals * 1 ether / oracle.getTokenPriceInUSD(10, 0x07D325030dA1A8c1f96C414BFFbe4fBD539CED45);
    }

    /// @notice Calculates token amount needed for monthly VIP subscription
    /// @param _monthCount Number of months
    /// @return Token amount needed
    function monthlyVIPAmountPay(uint256 _monthCount) public view returns (uint256) {
        return tokenAmountInUSD(vipPriceMonthly * _monthCount);
    }

    /// @notice Calculates token amount needed for fixed-count VIP subscription
    /// @param fixedCount Number of quotas
    /// @return Token amount needed
    function fixedCountVIPAmountPay(uint256 fixedCount) public view returns (uint256) {
        return tokenAmountInUSD(vipPriceFixedCount * fixedCount);
    }

    /// @notice Gets remaining quotas for an account
    /// @param _account Address of the account
    /// @return Number of remaining quotas
    function remainingAmount(address _account) public view returns (uint256) {
        VIPDetail memory vipDetail = address2VIPDetail[_account];

        if (vipDetail.tp == PayType.None) {
            return 0;
        }

        if (vipDetail.totalQuotas <= vipDetail.usedQuotas) {
            return 0;
        }

        if (vipDetail.tp == PayType.Monthly && block.timestamp > vipDetail.endAt) {
            return 0;
        }

        return vipDetail.totalQuotas - vipDetail.usedQuotas;
    }

    /// @notice Requests to use VIP quotas
    /// @param _quotas Number of quotas to use
    function request(uint256 _quotas) external {
        require(_quotas > 0, "_quotas zero");

        uint256 availableQuotas = remainingAmount(msg.sender);
        require(availableQuotas >= _quotas, "insufficient");

        bool useFreeRequest = tryUseFreeRequest();
        if (useFreeRequest) {
            return;
        }
        VIPDetail storage vipDetail = address2VIPDetail[msg.sender];
        vipDetail.usedQuotas += _quotas;

        emit requestVIP(msg.sender, _quotas);
    }

    /// @notice Checks if an address can purchase VIP subscription
    /// @param _user Address to check
    /// @param tp Type of VIP subscription
    /// @return Whether the address can purchase VIP subscription
    function canPayVIP(address _user, PayType tp) public view returns (bool) {
        VIPDetail memory existVIPDetail = address2VIPDetail[_user];
        if (existVIPDetail.tp == PayType.None) {
            return true;
        }

        if (existVIPDetail.tp == PayType.Monthly && block.timestamp >= existVIPDetail.endAt) {
            return true;
        }

        if (existVIPDetail.tp == PayType.FixedCount && existVIPDetail.usedQuotas >= existVIPDetail.totalQuotas) {
            return true;
        }

        if (existVIPDetail.tp == tp) {
            return true;
        }

        return false;
    }
}
