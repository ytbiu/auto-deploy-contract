// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IOracle {
    function getTokenPriceInUSD(uint32 secondsAgo, address token) external view returns (uint256);
}

interface IXAANFTHolder {
    function amountIncrByTokenId(address user, uint256 amount) external view returns (uint256);
    function userMaxTokenId(address user) external pure returns (uint256);
}

/**
 * @title XAAIAO
 * @dev This contract allows users to deposit the  TokenIn  during  deposit period.
 * After the distribution period begins, users can claim their proportional ERC20 rewards based on the amount of TokenIn they deposited.
 */
/// @custom:oz-upgrades-from OldXAAIAO
contract XAAIAO is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Address of the  ERC20 token contract
    IERC20 public tokenIn;
    IERC20 public rewardToken;
    IXAANFTHolder public xaaNFTHolder;
    // Total rewards to be distributed (in wei)
    uint256 public totalReward;

    // Deposit period:
    uint256 public depositPeriod;

    // Start and end timestamps for the deposit period
    uint256 public startTime;
    uint256 public endTime;

    // Total amount of tokenIn deposited in the contract
    uint256 public totalDepositedTokenIn;
    // Mapping to store the amount of TokenIn deposited by each user
    mapping(address => uint256) public userDeposits;

    uint256 public totalDepositedTokenInIncrByNFT;
    mapping(address => uint256) public userDepositsIncrByNFT;

    // Mapping to track whether a user has claimed their rewards
    mapping(address => bool) public hasClaimed;

    mapping(address => bool) public admins;

    IOracle public oracle;
    bool public succeed;

    uint256 public minDepositBalance = 1500 * 1e18;

    // Events

    event DepositTokenInIncrByNFT(address indexed user, uint256 amount);
    event DepositTokenIn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event TokenInClaimedBack(address indexed user, uint256 amount);
    event DepositedTokenClaimed(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable initializers to prevent unauthorized initialization of the implementation contract
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _tokenIn,
        address _rewardToken,
        uint256 _startTime,
        uint256 depositPeriodHours,
        uint256 _totalReward,
        address _xaaNFTHolder
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(owner);

        tokenIn = IERC20(_tokenIn);
        rewardToken = IERC20(_rewardToken);
        startTime = _startTime;
        depositPeriod = depositPeriodHours * 1 hours;
        endTime = _startTime + depositPeriod;
        totalReward = _totalReward;
        xaaNFTHolder = IXAANFTHolder(_xaaNFTHolder);
        oracle = IOracle(0x4bb48d5821cb668B663f74111D06D6B0060d2950);
    }

    /**
     * @dev Modifier to ensure the function is only called during the deposit period.
     */
    modifier onlyDuringDepositPeriod() {
        require(isStarted(), "Distribution not started");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Deposit period over");
        _;
    }

    /**
     * @dev Modifier to ensure the function is only called after the distribution period begins.
     */
    modifier onlyAfterDistribution() {
        require(isStarted(), "Distribution not started");
        require(block.timestamp > endTime, "Distribution not end");
        _;
    }

    modifier onlyAdminOrOwner() {
        require(admins[msg.sender] || msg.sender == owner(), "Only admin can call this function");
        _;
    }

    function start() external onlyOwner {
        require(isStarted() == false, "Distribution already started");
        startTime = block.timestamp;
        endTime = block.timestamp + depositPeriod;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20(_rewardToken);
    }

    function setTokenIn(address _tokenIn) external onlyOwner {
        tokenIn = IERC20(_tokenIn);
    }

    /**
     * @dev Allows users to claim their rewards after the distribution period begins.
     * The amount of rewards is proportional to the amount of Token In they deposited.
     * Emits a `RewardsClaimed` event.
     */
    function claimRewards() external onlyAfterDistribution {
        require(!hasClaimed[msg.sender], "Rewards already claimed");
        require(userDeposits[msg.sender] > 0, "No deposit found");

        if (isSuccess()) {
            if (!succeed) {
                succeed = true;
            }

            uint256 userReward = getReward(msg.sender);
            require(userReward > 0, "No reward found");

            // Mark rewards as claimed
            hasClaimed[msg.sender] = true;

            // Transfer rewards to the user
            require(rewardToken.transfer(msg.sender, userReward), "rewards transfer failed");

            emit RewardsClaimed(msg.sender, userReward);
        } else {
            hasClaimed[msg.sender] = true;
            uint256 tokenInAmount = userDeposits[msg.sender];
            require(tokenIn.transfer(msg.sender, tokenInAmount), "tokenIn transfer failed");
            emit TokenInClaimedBack(msg.sender, tokenInAmount);
        }
    }

    /**
     * @dev Returns the remaining time in the deposit period.
     * @return Remaining time in seconds, or 0 if the deposit period has ended.
     */
    function getRemainingTime() external view returns (uint256) {
        if (isStarted() == false) {
            return 0;
        }
        if (block.timestamp > endTime) {
            return 0;
        }
        return endTime - block.timestamp;
    }

    /**
     * @dev Allows the owner (admin) to claim any remaining TokenIn from the contract.
     * This function can only be called after the deposit period ends.
     */
    function claimDepositedToken() external onlyAfterDistribution onlyOwner {
        uint256 balance = tokenIn.balanceOf(address(this));
        require(balance > 0, "No balance claim");

        // Transfer all remaining TokenIn to the owner
        SafeERC20.safeTransfer(tokenIn, msg.sender, balance);
        emit DepositedTokenClaimed(balance);
    }

    /**
     * @dev Ensures that only the contract owner can authorize upgrades to the implementation contract.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function isStarted() public view returns (bool) {
        return block.timestamp >= startTime;
    }

    function getReward(address user) public view returns (uint256) {
        if (userDeposits[user] == 0) {
            return 0;
        }

        uint256 userReward = (userDepositsIncrByNFT[user] * totalReward) / totalDepositedTokenInIncrByNFT;
        return userReward;
    }

    function getOriginReward(address user) public view returns (uint256) {
        if (userDeposits[user] == 0) {
            return 0;
        }

        uint256 userReward = (userDeposits[user] * totalReward) / totalDepositedTokenInIncrByNFT;
        return userReward;
    }

    function deposit(uint256 amount) external onlyDuringDepositPeriod {
        require(amount > 0, "amount must be greater than 0");

        SafeERC20.safeTransferFrom(tokenIn, msg.sender, address(this), amount);
        // Record deposit
        userDeposits[msg.sender] += amount;
        totalDepositedTokenIn += amount;
        emit DepositTokenIn(msg.sender, amount);

        uint256 amountIncrByNFT = amount;
        if (address(xaaNFTHolder) != address(0)) {
            amountIncrByNFT = xaaNFTHolder.amountIncrByTokenId(msg.sender, amount);
            emit DepositTokenInIncrByNFT(msg.sender, amountIncrByNFT);
        }

        userDepositsIncrByNFT[msg.sender] += amountIncrByNFT;
        totalDepositedTokenInIncrByNFT += amountIncrByNFT;

        emit DepositTokenIn(msg.sender, amount);
    }

    function setXaaNFTHolder(address _xaaNFTHolder) external onlyOwner {
        xaaNFTHolder = IXAANFTHolder(_xaaNFTHolder);
    }

    function setTimeFor(uint256 _startTime, uint256 _endTime) external onlyAdminOrOwner {
        startTime = _startTime;
        endTime = _endTime;
    }


    function setMinDepositBalance(uint256 _minDepositBalance) external onlyOwner {
        minDepositBalance = _minDepositBalance;
    }
    function setAdmin(address _admin, bool _isAdmin) external onlyOwner {
        admins[_admin] = _isAdmin;
    }

    function getIncrInfo(address user)
        external
        view
        returns (uint256 orginDeposit, uint256 depositIncrByNFT, uint256 incrByNFTTier)
    {
        uint256 _deposit = userDeposits[user];
        depositIncrByNFT = userDepositsIncrByNFT[user];

        incrByNFTTier = xaaNFTHolder.userMaxTokenId(user);

        return (_deposit, depositIncrByNFT, incrByNFTTier);
    }

    function isSuccess() public view returns (bool) {
        require(block.timestamp >= endTime, "Distribution not end");
        if (succeed) {
            return true;
        }
        uint256 tokenInPrice = oracle.getTokenPriceInUSD(10, address(tokenIn));
        uint256 tokenInAmount = tokenIn.balanceOf(address(this));
        uint256 tokenInUSD = tokenInAmount * tokenInPrice;
        return tokenInUSD >= minDepositBalance * 1e6;
    }
}
