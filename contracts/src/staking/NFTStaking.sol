// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interface/IRewardToken.sol";
import "./interface/IRentContract.sol";
import "./interface/IDBCAIContract.sol";
import "./interface/ILongStakeContract.sol";

import "forge-std/console.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RewardCalculatorLib} from "./library/RewardCalculatorLib.sol";
import {ToolLib} from "./library/ToolLib.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:oz-upgrades-from OldNFTStaking
contract NFTStaking is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC1155Receiver
{
    uint8 public constant SECONDS_PER_BLOCK = 6;
    uint256 public constant BASE_RESERVE_AMOUNT = 10_000 ether;
    uint256 public constant REWARD_DURATION = 60 days;
    uint8 public constant MAX_NFTS_PER_MACHINE = 20;
    uint256 public constant LOCK_PERIOD = 180 days;
    StakingType public constant STAKING_TYPE = StakingType.LongTerm;

    string public projectName;

    IDBCAIContract public dbcAIContract;
    IERC1155 public nftToken;
    IRewardToken public rewardToken;
    address public longStakeContractAddress;

    address public canUpgradeAddress;
    uint256 public totalDistributedRewardAmount;
    uint256 public rewardStartAtTimestamp;

    uint256 public rewardAmountPerYear;
    bool public depositedReward;

    uint256 public totalAdjustUnit;
    uint256 public dailyRewardAmount;

    uint256 public totalReservedAmount;
    uint256 public totalGpuCount;
    uint256 public totalCalcPoint;
    address public slashPayToAddress;

    uint256 public totalStakingGpuCount;
    RewardCalculatorLib.RewardsPerShare public rewardsPerCalcPoint;

    string[] public stakedMachineIds;

    enum StakingType {
        ShortTerm,
        LongTerm,
        Free
    }

    enum NotifyType {
        ContractRegister,
        MachineRegister,
        MachineUnregister,
        MachineOnline,
        MachineOfflineOnIdle,
        MachineOfflineOnBusy
    }

    struct SlashInfo {
        address stakeHolder;
        string machineId;
        uint256 slashAmount;
        uint256 createdAt;
        bool paid;
    }

    struct LockedRewardDetail {
        uint256 totalAmount;
        uint256 lockTime;
        uint256 unlockTime;
        uint256 claimedAmount;
    }

    struct ApprovedReportInfo {
        address renter;
    }

    struct StakeInfo {
        address holder;
        uint256 startAtTimestamp;
        uint256 lastClaimAtTimestamp;
        uint256 endAtTimestamp;
        uint256 calcPoint;
        uint256 reservedAmount;
        uint256[] nftTokenIds;
        uint256[] tokenIdBalances;
        uint256 nftCount;
        uint256 claimedAmount;
        bool isRentedByUser;
        uint256 gpuCount;
        uint256 nextRenterCanRentAt;
    }

    mapping(address => bool) public clientWalletAddress;
    mapping(address => string[]) public holder2MachineIds;
    mapping(string => LockedRewardDetail[]) public machineId2LockedRewardDetails;
    mapping(string => ApprovedReportInfo[]) private pendingSlashedMachineId2Renter;
    mapping(string => StakeInfo) public machineId2StakeInfos;
    mapping(string => LockedRewardDetail) public machineId2LockedRewardDetail;
    mapping(string => bool) public machineId2Rented;
    mapping(string => RewardCalculatorLib.UserRewards) public machineId2StakeUnitRewards;
    mapping(string => bool) private statedMachinesMap;
    mapping(uint256 => SlashInfo) public slashId2SlashInfo;
    mapping(string => uint256) public machine2LastSlashId;

    event Staked(address indexed stakeholder, string machineId, uint256 originCalcPoint, uint256 calcPoint);

    event StakedGPUType(string machineId, string gpuType);
    event AddedStakeHours(address indexed stakeholder, string machineId, uint256 stakeHours);

    event Reserve(string machineId, uint256 amount);
    event Unstaked(address indexed stakeholder, string machineId, uint256 paybackReserveAmount);
    event Claimed(
        address indexed stakeholder,
        string machineId,
        uint256 totalRewardAmount,
        uint256 moveToUserWalletAmount,
        uint256 moveToReservedAmount,
        bool paidSlash
    );

    event PaySlash(string machineId, address renter, uint256 slashAmount);
    event RentMachine(address indexed machineOwner, string machineId, uint256 rentFee);
    event EndRentMachine(address indexed machineOwner, string machineId, uint256 nextCanRentTime);
    event ReportMachineFault(string machineId, uint256 slashId, address renter);
    event RewardsPerCalcPointUpdate(uint256 accumulatedPerShareBefore, uint256 accumulatedPerShareAfter);
    event MoveToReserveAmount(string machineId, address holder, uint256 amount);
    event RenewRent(string machineId, address holder, uint256 rentFee);
    event ExitStakingForOffline(string machineId, address holder);

    // error

    error CallerNotRentContract();
    error ZeroAddress();
    error AddressExists();
    error CanNotUpgrade(address);
    error TimestampLessThanCurrent();
    error MachineNotStaked(string machineId);
    error MachineIsStaking(string machineId);
    error StakeAmountLessThanReserve(string machineId, uint256 amount);
    error MemorySizeLessThan16G(uint256 mem);
    error GPUTypeNotMatch(string gpuType);
    error ZeroCalcPoint();
    error InvalidNFTLength(uint256 tokenIdLength, uint256 balanceLength);
    error NotMachineOwner(address);
    error ZeroNFTTokenIds();
    error NFTCountGreaterThan20();
    error NotPaidSlashBeforeClaim(string machineId, uint256 slashAmount);
    error NotStakeHolder(string machineId, address currentAddress);
    error MachineRentedByUser();
    error MachineNotRented();
    error NotAdmin();
    error MachineNotStakeEnoughDBC();
    error InvalidStakeHours();
    error RewardEnd();
    error MachineNotOnlineOrRegistered();
    error NotMachineOwnerOrAdmin();
    error MachineStillRegistered();
    error StakingInLongTerm();
    error IsStaking();
    error ShouldPaySlashBeforeStake();
    error InRenting();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function onERC1155BatchReceived(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC1155Received(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256, /* unusedParameter */
        uint256, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    modifier onlyClientWallet() {
        require(clientWalletAddress[msg.sender], NotAdmin());
        _;
    }

    modifier onlyDBCAIContract() {
        require(msg.sender == address(dbcAIContract), "only dbc AI contract");
        _;
    }

    function initialize(
        string memory _projectName,
        address _initialOwner,
        address _nftToken,
        address _rewardToken,
        address _dbcAIContract,
        uint256 _rewardAmountPerYear
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        projectName = _projectName;
        rewardToken = IRewardToken(_rewardToken);
        nftToken = IERC1155(_nftToken);
        dbcAIContract = IDBCAIContract(_dbcAIContract);

        rewardAmountPerYear = _rewardAmountPerYear;
        dailyRewardAmount = rewardAmountPerYear / 365 days;
        canUpgradeAddress = msg.sender;
        rewardStartAtTimestamp = block.timestamp;
        rewardsPerCalcPoint.lastUpdated = block.timestamp;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), ZeroAddress());
        require(msg.sender == canUpgradeAddress, CanNotUpgrade(msg.sender));
    }

    function setUpgradeAddress(address addr) external onlyOwner {
        canUpgradeAddress = addr;
    }

    function setRewardToken(address token) external onlyOwner {
        rewardToken = IRewardToken(token);
    }

    function setNftToken(address token) external onlyOwner {
        nftToken = IERC1155(token);
    }

    function setLongStakeContract(address _longStakeContract) public onlyOwner {
        longStakeContractAddress = _longStakeContract;
    }

    function setRewardStartAt(uint256 timestamp) external onlyOwner {
        require(timestamp >= block.timestamp, TimestampLessThanCurrent());
        rewardStartAtTimestamp = timestamp;
    }

    function setClientWallets(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            require(addrs[i] != address(0), ZeroAddress());
            require(clientWalletAddress[addrs[i]] == false, AddressExists());
            clientWalletAddress[addrs[i]] = true;
        }
    }

    function setDBCAIContract(address addr) external onlyOwner {
        dbcAIContract = IDBCAIContract(addr);
    }

    function addTokenToStake(string memory machineId, uint256 amount) external nonReentrant {
        require(isStaking(machineId), MachineNotStaked(machineId));
        if (amount == 0) {
            return;
        }
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        ApprovedReportInfo[] memory approvedReportInfos = pendingSlashedMachineId2Renter[machineId];

        if (approvedReportInfos.length > 0) {
            require(
                amount == BASE_RESERVE_AMOUNT * approvedReportInfos.length,
                StakeAmountLessThanReserve(machineId, amount)
            );
            for (uint8 i = 0; i < approvedReportInfos.length; i++) {
                // pay slash to renters
                payToRenterForSlashing(machineId, stakeInfo, approvedReportInfos[i].renter, false);
                amount -= BASE_RESERVE_AMOUNT;
            }
            delete pendingSlashedMachineId2Renter[machineId];
        }

        _joinStaking(machineId, stakeInfo.calcPoint, amount + stakeInfo.reservedAmount);
        emit Reserve(machineId, amount);
    }

    function revertIfMachineInfoCanNotStake(uint256 calcPoint, string memory gpuType, uint256 mem) internal pure {
        require(mem >= 16, MemorySizeLessThan16G(mem));
        require(ToolLib.checkString(gpuType), GPUTypeNotMatch(gpuType));
        require(calcPoint > 0, ZeroCalcPoint());
    }

    function _tryInitMachineLockRewardInfo(string memory machineId, uint256 currentTime) internal {
        if (machineId2LockedRewardDetail[machineId].lockTime == 0) {
            machineId2LockedRewardDetail[machineId] = LockedRewardDetail({
                totalAmount: 0,
                lockTime: currentTime,
                unlockTime: currentTime + LOCK_PERIOD,
                claimedAmount: 0
            });
        }
    }

    modifier canStake(
        address stakeholder,
        string memory machineId,
        uint256[] memory nftTokenIds,
        uint256[] memory nftTokenIdBalances
    ) {
        require(pendingSlashedMachineId2Renter[machineId].length == 0, ShouldPaySlashBeforeStake());
        require(clientWalletAddress[msg.sender], NotAdmin());
        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        require(stakeInfo.nftTokenIds.length == 0, IsStaking());
        require(dbcAIContract.freeGpuAmount(machineId) >= 1, MachineNotStakeEnoughDBC());
        require(
            nftTokenIds.length == nftTokenIdBalances.length,
            InvalidNFTLength(nftTokenIds.length, nftTokenIdBalances.length)
        );

        require(!rewardEnd(), RewardEnd());
        (bool isOnline, bool isRegistered) = dbcAIContract.getMachineState(machineId, projectName, STAKING_TYPE);
        require(isOnline && isRegistered, MachineNotOnlineOrRegistered());
        require(!isStaking(machineId), MachineIsStaking(machineId));
        require(nftTokenIds.length > 0, ZeroNFTTokenIds());
        if (longStakeContractAddress != address(0)) {
            require(!ILongStakeContract(longStakeContractAddress).isStaking(machineId), StakingInLongTerm());
        }
        _;
    }

    function stake(
        address stakeholder,
        string calldata machineId,
        uint256[] calldata nftTokenIds,
        uint256[] calldata nftTokenIdBalances
    ) external canStake(stakeholder, machineId, nftTokenIds, nftTokenIdBalances) nonReentrant {
        (address machineOwner, uint256 calcPoint,, string memory gpuType,,,,, uint256 mem) =
            dbcAIContract.getMachineInfo(machineId, true);
        require(machineOwner == stakeholder, NotMachineOwner(machineOwner));
        revertIfMachineInfoCanNotStake(calcPoint, gpuType, mem);

        uint256 nftCount = getNFTCount(nftTokenIdBalances);
        require(nftCount <= MAX_NFTS_PER_MACHINE, NFTCountGreaterThan20());
        uint256 originCalcPoint = calcPoint;
        calcPoint = calcPoint * nftCount;
        uint256 currentTime = block.timestamp;
        uint256 stakeEndAt = 0;
        uint8 gpuCount = 1;
        if (!statedMachinesMap[machineId]) {
            statedMachinesMap[machineId] = true;
            totalGpuCount += gpuCount;
        }
        totalStakingGpuCount += gpuCount;

        nftToken.safeBatchTransferFrom(stakeholder, address(this), nftTokenIds, nftTokenIdBalances, "transfer");
        machineId2StakeInfos[machineId] = StakeInfo({
            startAtTimestamp: currentTime,
            lastClaimAtTimestamp: currentTime,
            endAtTimestamp: stakeEndAt,
            calcPoint: 0,
            reservedAmount: 0,
            nftTokenIds: nftTokenIds,
            tokenIdBalances: nftTokenIdBalances,
            nftCount: nftCount,
            holder: stakeholder,
            claimedAmount: 0,
            isRentedByUser: false,
            gpuCount: gpuCount,
            nextRenterCanRentAt: currentTime
        });

        _joinStaking(machineId, calcPoint, 0);
        _tryInitMachineLockRewardInfo(machineId, currentTime);

        holder2MachineIds[stakeholder].push(machineId);
        dbcAIContract.reportStakingStatus(projectName, StakingType.ShortTerm, machineId, 1, true);
        emit Staked(stakeholder, machineId, originCalcPoint, calcPoint);
        emit StakedGPUType(machineId, gpuType);
    }

    function getPendingSlashCount(string memory machineId) public view returns (uint256) {
        return pendingSlashedMachineId2Renter[machineId].length;
    }

    function getRewardInfo(string memory machineId)
        public
        view
        returns (uint256 newRewardAmount, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount)
    {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        uint256 totalRewardAmount = calculateRewards(machineId);
        (uint256 _canClaimAmount, uint256 _lockedAmount) = _getRewardDetail(totalRewardAmount);
        (uint256 releaseAmount, uint256 lockedAmountBefore) = calculateReleaseReward(machineId);

        return (
            totalRewardAmount,
            _canClaimAmount + releaseAmount,
            _lockedAmount + lockedAmountBefore,
            stakeInfo.claimedAmount
        );
    }

    function getNFTCount(uint256[] memory nftTokenIdBalances) internal pure returns (uint256 nftCount) {
        for (uint256 i = 0; i < nftTokenIdBalances.length; i++) {
            nftCount += nftTokenIdBalances[i];
        }

        return nftCount;
    }

    function _claim(string memory machineId) internal {
        if (!rewardStart()) {
            return;
        }

        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        uint256 machineShares = _getMachineShares(stakeInfo.calcPoint, stakeInfo.reservedAmount);
        _updateMachineRewards(machineId, machineShares);

        address stakeholder = stakeInfo.holder;
        uint256 currentTimestamp = block.timestamp;

        bool _isStaking = isStaking(machineId);
        uint256 rewardAmount = calculateRewards(machineId);

        machineId2StakeUnitRewards[machineId].accumulated = 0;

        (uint256 canClaimAmount, uint256 lockedAmount) = _getRewardDetail(rewardAmount);

        (uint256 _dailyReleaseAmount,) = calculateReleaseRewardAndUpdate(machineId);
        canClaimAmount += _dailyReleaseAmount;

        ApprovedReportInfo[] storage approvedReportInfos = pendingSlashedMachineId2Renter[machineId];
        bool slashed = approvedReportInfos.length > 0;
        uint256 moveToReserveAmount = 0;
        if (canClaimAmount > 0 && (_isStaking || slashed)) {
            if (stakeInfo.reservedAmount < BASE_RESERVE_AMOUNT) {
                (uint256 _moveToReserveAmount, uint256 leftAmountCanClaim) =
                    tryMoveReserve(machineId, canClaimAmount, stakeInfo);
                canClaimAmount = leftAmountCanClaim;
                moveToReserveAmount = _moveToReserveAmount;
            }
        }

        bool paidSlash = false;
        if (slashed && stakeInfo.reservedAmount >= BASE_RESERVE_AMOUNT) {
            ApprovedReportInfo memory lastSlashInfo = approvedReportInfos[approvedReportInfos.length - 1];
            payToRenterForSlashing(machineId, stakeInfo, lastSlashInfo.renter, true);
            approvedReportInfos.pop();
            paidSlash = true;
        }

        if (stakeInfo.reservedAmount < BASE_RESERVE_AMOUNT && _isStaking) {
            (uint256 _moveToReserveAmount, uint256 leftAmountCanClaim) =
                tryMoveReserve(machineId, canClaimAmount, stakeInfo);
            canClaimAmount = leftAmountCanClaim;
            moveToReserveAmount = _moveToReserveAmount;
        }

        if (canClaimAmount > 0) {
            SafeERC20.safeTransfer(rewardToken, stakeholder, canClaimAmount);
        }

        uint256 totalRewardAmount = canClaimAmount + moveToReserveAmount;
        totalDistributedRewardAmount += totalRewardAmount;
        stakeInfo.claimedAmount += totalRewardAmount;
        stakeInfo.lastClaimAtTimestamp = currentTimestamp;

        if (lockedAmount > 0) {
            machineId2LockedRewardDetail[machineId].totalAmount += lockedAmount;
        }

        emit Claimed(
            stakeholder, machineId, rewardAmount + _dailyReleaseAmount, canClaimAmount, moveToReserveAmount, paidSlash
        );
    }

    function getMachineIdsByStakeholder(address holder) external view returns (string[] memory) {
        return holder2MachineIds[holder];
    }

    function getAllRewardInfo(address holder)
        external
        view
        returns (uint256 availableRewardAmount, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount)
    {
        string[] memory machineIds = holder2MachineIds[holder];
        for (uint256 i = 0; i < machineIds.length; i++) {
            (uint256 _availableRewardAmount, uint256 _canClaimAmount, uint256 _lockedAmount, uint256 _claimedAmount) =
                getRewardInfo(machineIds[i]);
            availableRewardAmount += _availableRewardAmount;
            canClaimAmount += _canClaimAmount;
            lockedAmount += _lockedAmount;
            claimedAmount += _claimedAmount;
        }
        return (availableRewardAmount, canClaimAmount, lockedAmount, claimedAmount);
    }

    function claimAll() external {
        string[] memory machineIds = holder2MachineIds[msg.sender];
        for (uint256 i = 0; i < machineIds.length; i++) {
            claim(machineIds[i]);
        }
    }

    function claim(string memory machineId) public {
        address stakeholder = msg.sender;
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        require(
            getPendingSlashCount(machineId) == 0,
            NotPaidSlashBeforeClaim(machineId, getPendingSlashCount(machineId) * BASE_RESERVE_AMOUNT)
        );

        require(stakeInfo.holder == stakeholder, NotStakeHolder(machineId, stakeholder));
        //        require(block.timestamp - stakeInfo.lastClaimAtTimestamp >= 1 days, "last claim less than 1 day");

        _claim(machineId);
    }

    function tryMoveReserve(string memory machineId, uint256 canClaimAmount, StakeInfo storage stakeInfo)
        internal
        returns (uint256 moveToReserveAmount, uint256 leftAmountCanClaim)
    {
        uint256 leftAmountShouldReserve = BASE_RESERVE_AMOUNT - stakeInfo.reservedAmount;
        if (canClaimAmount >= leftAmountShouldReserve) {
            canClaimAmount -= leftAmountShouldReserve;
            moveToReserveAmount = leftAmountShouldReserve;
        } else {
            moveToReserveAmount = canClaimAmount;
            canClaimAmount = 0;
        }

        // the amount should be transfer to reserve
        totalReservedAmount += moveToReserveAmount;
        stakeInfo.reservedAmount += moveToReserveAmount;
        if (moveToReserveAmount > 0) {
            emit MoveToReserveAmount(machineId, stakeInfo.holder, moveToReserveAmount);
        }
        return (moveToReserveAmount, canClaimAmount);
    }

    function calculateReleaseRewardAndUpdate(string memory machineId)
        internal
        returns (uint256 releaseAmount, uint256 lockedAmount)
    {
        LockedRewardDetail storage lockedRewardDetail = machineId2LockedRewardDetail[machineId];
        if (lockedRewardDetail.totalAmount > 0 && lockedRewardDetail.totalAmount == lockedRewardDetail.claimedAmount) {
            return (0, 0);
        }

        if (block.timestamp > lockedRewardDetail.unlockTime) {
            releaseAmount = lockedRewardDetail.totalAmount - lockedRewardDetail.claimedAmount;
            lockedRewardDetail.claimedAmount = lockedRewardDetail.totalAmount;
            return (releaseAmount, 0);
        }

        uint256 totalUnlocked =
            (block.timestamp - lockedRewardDetail.lockTime) * lockedRewardDetail.totalAmount / LOCK_PERIOD;
        releaseAmount = totalUnlocked - lockedRewardDetail.claimedAmount;
        lockedRewardDetail.claimedAmount += releaseAmount;
        return (releaseAmount, lockedRewardDetail.totalAmount - releaseAmount);
    }

    function calculateReleaseReward(string memory machineId)
        public
        view
        returns (uint256 releaseAmount, uint256 lockedAmount)
    {
        LockedRewardDetail storage lockedRewardDetail = machineId2LockedRewardDetail[machineId];
        if (lockedRewardDetail.totalAmount > 0 && lockedRewardDetail.totalAmount == lockedRewardDetail.claimedAmount) {
            return (0, 0);
        }

        if (block.timestamp > lockedRewardDetail.unlockTime) {
            releaseAmount = lockedRewardDetail.totalAmount - lockedRewardDetail.claimedAmount;
            return (releaseAmount, 0);
        }

        uint256 totalUnlocked =
            (block.timestamp - lockedRewardDetail.lockTime) * lockedRewardDetail.totalAmount / LOCK_PERIOD;
        releaseAmount = totalUnlocked - lockedRewardDetail.claimedAmount;
        return (releaseAmount, lockedRewardDetail.totalAmount - releaseAmount);
    }

    function unStake(string calldata machineId) public nonReentrant {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        require(stakeInfo.startAtTimestamp > 0, MachineNotStaked(machineId));
        require(block.timestamp >= stakeInfo.endAtTimestamp, MachineNotStaked(machineId));
        require(!stakeInfo.isRentedByUser, MachineRentedByUser());
        (, bool isRegistered) = dbcAIContract.getMachineState(machineId, projectName, STAKING_TYPE);
        require(!isRegistered, MachineStillRegistered());
        _claim(machineId);
        _unStake(machineId, stakeInfo.holder);
    }

    function forceUnStake(string calldata machineId) internal nonReentrant {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        _claim(machineId);
        _unStake(machineId, stakeInfo.holder);
        emit ExitStakingForOffline(machineId, stakeInfo.holder);
    }

    function unStakeByHolder(string calldata machineId) public nonReentrant {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        require(msg.sender == stakeInfo.holder, NotStakeHolder(machineId, msg.sender));
        require(stakeInfo.startAtTimestamp > 0, MachineNotStaked(machineId));
        require(stakeInfo.isRentedByUser == false, MachineRentedByUser());
        (, bool isRegistered) = dbcAIContract.getMachineState(machineId, projectName, STAKING_TYPE);
        require(!isRegistered, MachineStillRegistered());

        require(machineId2Rented[machineId] == false, InRenting());
        _claim(machineId);
        _unStake(machineId, stakeInfo.holder);
    }

    function _unStake(string memory machineId, address stakeholder) internal {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        uint256 reservedAmount = stakeInfo.reservedAmount;

        if (reservedAmount > 0) {
            SafeERC20.safeTransfer(rewardToken, stakeholder, reservedAmount);
            stakeInfo.reservedAmount = 0;
            totalReservedAmount = totalReservedAmount > reservedAmount ? totalReservedAmount - reservedAmount : 0;
        }

        stakeInfo.endAtTimestamp = block.timestamp;
        nftToken.safeBatchTransferFrom(
            address(this), stakeholder, stakeInfo.nftTokenIds, stakeInfo.tokenIdBalances, "transfer"
        );
        stakeInfo.nftTokenIds = new uint256[](0);
        stakeInfo.tokenIdBalances = new uint256[](0);
        stakeInfo.nftCount = 0;
        _joinStaking(machineId, 0, 0);
        removeStakingMachineFromHolder(stakeholder, machineId);
        if (totalStakingGpuCount > 0) {
            totalStakingGpuCount -= 1;
        }

        dbcAIContract.reportStakingStatus(projectName, StakingType.ShortTerm, machineId, 1, false);
        emit Unstaked(stakeholder, machineId, reservedAmount);
    }

    function removeStakingMachineFromHolder(address holder, string memory machineId) internal {
        string[] storage machineIds = holder2MachineIds[holder];
        for (uint256 i = 0; i < machineIds.length; i++) {
            if (keccak256(abi.encodePacked(machineIds[i])) == keccak256(abi.encodePacked(machineId))) {
                machineIds[i] = machineIds[machineIds.length - 1];
                machineIds.pop();
                break;
            }
        }
    }

    function getStakeHolder(string calldata machineId) external view returns (address) {
        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        return stakeInfo.holder;
    }

    function isStaking(string memory machineId) public view returns (bool) {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        bool _isStaking = stakeInfo.holder != address(0) && stakeInfo.startAtTimestamp > 0;
        if (stakeInfo.endAtTimestamp != 0) {
            _isStaking = _isStaking && block.timestamp < stakeInfo.endAtTimestamp;
        }
        return _isStaking;
    }

    function tryPaySlashOnReport(
        StakeInfo memory stakeInfo,
        string memory machineId,
        uint256 slashId,
        address _slashToPayAddress
    ) internal {
        if (stakeInfo.reservedAmount >= BASE_RESERVE_AMOUNT) {
            payToRenterForSlashing(machineId, stakeInfo, _slashToPayAddress, true);
            slashId2SlashInfo[slashId].paid = true;
        }
    }

    function getMachineInfo(string memory machineId)
        external
        view
        returns (
            address holder,
            uint256 calcPoint,
            uint256 startAtTimestamp,
            uint256 endAtTimestamp,
            uint256 nextRenterCanRentAt,
            uint256 reservedAmount,
            bool isOnline,
            bool isRegistered
        )
    {
        StakeInfo memory info = machineId2StakeInfos[machineId];
        (bool _isOnline, bool _isRegistered) = dbcAIContract.getMachineState(machineId, projectName, STAKING_TYPE);
        return (
            info.holder,
            info.calcPoint,
            info.startAtTimestamp,
            info.endAtTimestamp,
            info.nextRenterCanRentAt,
            info.reservedAmount,
            _isOnline,
            _isRegistered
        );
    }

    function payToRenterForSlashing(
        string memory machineId,
        StakeInfo memory stakeInfo,
        address slashToPayAddress,
        bool alreadyStaked
    ) internal {
        if (alreadyStaked) {
            _joinStaking(machineId, stakeInfo.calcPoint, stakeInfo.reservedAmount - BASE_RESERVE_AMOUNT);
        }
        rewardToken.transfer(slashToPayAddress, BASE_RESERVE_AMOUNT);

        //        paidSlash(machineId);
        emit PaySlash(machineId, slashToPayAddress, BASE_RESERVE_AMOUNT);
    }

    function getGlobalState() external view returns (uint256, uint256, uint256) {
        return (totalCalcPoint, totalReservedAmount, rewardStartAtTimestamp + REWARD_DURATION);
    }

    function _getRewardDetail(uint256 totalRewardAmount)
        internal
        pure
        returns (uint256 canClaimAmount, uint256 lockedAmount)
    {
        uint256 releaseImmediateAmount = totalRewardAmount / 10;
        uint256 releaseLinearLockedAmount = totalRewardAmount - releaseImmediateAmount;
        return (releaseImmediateAmount, releaseLinearLockedAmount);
    }

    function getReward(string memory machineId) external view returns (uint256) {
        return calculateRewards(machineId);
    }

    function getDailyRewardAmount() public view returns (uint256) {
        uint256 remainingSupply = rewardAmountPerYear - totalDistributedRewardAmount;
        if (dailyRewardAmount > remainingSupply) {
            return remainingSupply;
        }
        return dailyRewardAmount;
    }

    function rewardStart() internal view returns (bool) {
        return rewardStartAtTimestamp > 0 && block.timestamp >= rewardStartAtTimestamp;
    }

    function _updateRewardPerCalcPoint() internal {
        uint256 accumulatedPerShareBefore = rewardsPerCalcPoint.accumulatedPerShare;
        rewardsPerCalcPoint = _getUpdatedRewardPerCalcPoint();
        emit RewardsPerCalcPointUpdate(accumulatedPerShareBefore, rewardsPerCalcPoint.accumulatedPerShare);
    }

    function _getUpdatedRewardPerCalcPoint() internal view returns (RewardCalculatorLib.RewardsPerShare memory) {
        uint256 rewardsPerSeconds = (getDailyRewardAmount()) / 1 days;
        if (rewardStartAtTimestamp == 0) {
            return RewardCalculatorLib.RewardsPerShare(0, 0);
        }
        //        uint256 rewardEndAt = Math.min(rewardStartAtTimestamp + REWARD_DURATION, stakeEndAtTimestamp);
        uint256 rewardEndAt = rewardStartAtTimestamp + REWARD_DURATION;

        RewardCalculatorLib.RewardsPerShare memory rewardsPerTokenUpdated = RewardCalculatorLib.getUpdateRewardsPerShare(
            rewardsPerCalcPoint, totalAdjustUnit, rewardsPerSeconds, rewardStartAtTimestamp, rewardEndAt
        );
        return rewardsPerTokenUpdated;
    }

    function _updateMachineRewards(string memory machineId, uint256 machineShares) internal {
        _updateRewardPerCalcPoint();

        RewardCalculatorLib.UserRewards memory machineRewards = machineId2StakeUnitRewards[machineId];
        if (machineRewards.lastAccumulatedPerShare == 0) {
            machineRewards.lastAccumulatedPerShare = rewardsPerCalcPoint.accumulatedPerShare;
        }
        RewardCalculatorLib.UserRewards memory machineRewardsUpdated =
            RewardCalculatorLib.getUpdateUserRewards(machineRewards, machineShares, rewardsPerCalcPoint);
        machineId2StakeUnitRewards[machineId] = machineRewardsUpdated;
    }

    function _getMachineShares(uint256 calcPoint, uint256 reservedAmount) public pure returns (uint256) {
        return
            calcPoint * ToolLib.LnUint256(reservedAmount > BASE_RESERVE_AMOUNT ? reservedAmount : BASE_RESERVE_AMOUNT);
    }

    function _joinStaking(string memory machineId, uint256 calcPoint, uint256 reserveAmount) internal {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        uint256 oldLnReserved = ToolLib.LnUint256(
            stakeInfo.reservedAmount > BASE_RESERVE_AMOUNT ? stakeInfo.reservedAmount : BASE_RESERVE_AMOUNT
        );

        uint256 machineShares = stakeInfo.calcPoint * oldLnReserved;

        uint256 newLnReserved =
            ToolLib.LnUint256(reserveAmount > BASE_RESERVE_AMOUNT ? reserveAmount : BASE_RESERVE_AMOUNT);

        totalAdjustUnit -= stakeInfo.calcPoint * oldLnReserved;
        totalAdjustUnit += calcPoint * newLnReserved;

        // update machine rewards
        _updateMachineRewards(machineId, machineShares);

        totalCalcPoint = totalCalcPoint - stakeInfo.calcPoint + calcPoint;

        stakeInfo.calcPoint = calcPoint;
        if (reserveAmount > stakeInfo.reservedAmount) {
            SafeERC20.safeTransferFrom(
                rewardToken, stakeInfo.holder, address(this), reserveAmount - stakeInfo.reservedAmount
            );
        }
        if (reserveAmount != stakeInfo.reservedAmount) {
            totalReservedAmount = totalReservedAmount + reserveAmount - stakeInfo.reservedAmount;
            stakeInfo.reservedAmount = reserveAmount;
        }
    }

    function calculateRewards(string memory machineId) public view returns (uint256) {
        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        if (stakeInfo.lastClaimAtTimestamp > stakeInfo.endAtTimestamp && stakeInfo.endAtTimestamp > 0) {
            return 0;
        }
        uint256 machineShares = _getMachineShares(stakeInfo.calcPoint, stakeInfo.reservedAmount);

        RewardCalculatorLib.UserRewards memory machineRewards = machineId2StakeUnitRewards[machineId];

        RewardCalculatorLib.RewardsPerShare memory currentRewardPerCalcPoint = _getUpdatedRewardPerCalcPoint();
        uint256 v = machineRewards.lastAccumulatedPerShare;
        if (machineRewards.lastAccumulatedPerShare == 0) {
            v = rewardsPerCalcPoint.accumulatedPerShare;
        }
        uint256 rewardAmount = RewardCalculatorLib.calculatePendingUserRewards(
            machineShares, v, currentRewardPerCalcPoint.accumulatedPerShare
        );

        return machineRewards.accumulated + rewardAmount;
    }

    function rewardEnd() public view returns (bool) {
        if (rewardStartAtTimestamp == 0) {
            return false;
        }
        return (block.timestamp > rewardStartAtTimestamp + REWARD_DURATION);
    }

    function getRewardEndAtTimestamp(uint256 stakeEndAtTimestamp) internal view returns (uint256) {
        uint256 rewardEndAt = rewardStartAtTimestamp + REWARD_DURATION;
        uint256 currentTime = block.timestamp;
        if (stakeEndAtTimestamp > rewardEndAt) {
            return rewardEndAt;
        } else if (stakeEndAtTimestamp > currentTime && stakeEndAtTimestamp - currentTime <= 1 hours) {
            return stakeEndAtTimestamp > 1 hours ? stakeEndAtTimestamp - 1 hours : 0;
        }
        if (stakeEndAtTimestamp != 0 && stakeEndAtTimestamp < currentTime) {
            return stakeEndAtTimestamp;
        }
        return currentTime;
    }

    function getRewardStartTime(uint256 _rewardStartAtTimestamp) public view returns (uint256) {
        if (_rewardStartAtTimestamp == 0) {
            return 0;
        }
        if (block.timestamp > _rewardStartAtTimestamp) {
            uint256 timeDuration = block.timestamp - _rewardStartAtTimestamp;
            return block.timestamp - timeDuration;
        }

        return block.timestamp + (_rewardStartAtTimestamp - block.timestamp);
    }

    function oneDayAccumulatedPerShare(uint256 currentAccumulatedPerShare, uint256 totalShares)
        internal
        view
        returns (uint256)
    {
        uint256 elapsed = 1 days;
        uint256 rewardsRate = (getDailyRewardAmount()) / 1 days;

        uint256 accumulatedPerShare = currentAccumulatedPerShare + 1 ether * elapsed * rewardsRate / totalShares;

        return accumulatedPerShare;
    }

    function preCalculateRewards(uint256 calcPoint, uint256 nftCount, uint256 reserveAmount)
        public
        view
        returns (uint256)
    {
        calcPoint = calcPoint * nftCount;
        uint256 machineShares = _getMachineShares(calcPoint, reserveAmount);
        uint256 machineAccumulatedPerShare = rewardsPerCalcPoint.accumulatedPerShare;

        uint256 totalShares = totalAdjustUnit + machineShares;

        uint256 _oneDayAccumulatedPerShare = oneDayAccumulatedPerShare(machineAccumulatedPerShare, totalShares);

        uint256 rewardAmount = RewardCalculatorLib.calculatePendingUserRewards(
            machineShares, machineAccumulatedPerShare, _oneDayAccumulatedPerShare
        );

        return rewardAmount;
    }

    function notify(NotifyType tp, string calldata machineId) external onlyDBCAIContract returns (bool) {
        if (tp == NotifyType.ContractRegister) {
            return true;
        }

        bool _isStaking = isStaking(machineId);
        if (!_isStaking) {
            return false;
        }

        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        if (tp == NotifyType.MachineOfflineOnBusy) {
            SlashInfo memory slashInfo = newSlashInfo(stakeInfo.holder, machineId, BASE_RESERVE_AMOUNT);
            addSlashInfoAndReport(slashInfo);
        } else if (tp == NotifyType.MachineOfflineOnIdle) {
            forceUnStake(machineId);
        }

        return true;
    }

    function newSlashInfo(address slasher, string memory machineId, uint256 slashAmount)
        internal
        view
        returns (SlashInfo memory)
    {
        SlashInfo memory slashInfo = SlashInfo({
            stakeHolder: slasher,
            machineId: machineId,
            slashAmount: slashAmount,
            createdAt: block.timestamp,
            paid: false
        });
        return slashInfo;
    }

    function addSlashInfoAndReport(SlashInfo memory slashInfo) internal {
        uint256 slashId = machine2LastSlashId[slashInfo.machineId];
        slashId++;
        machine2LastSlashId[slashInfo.machineId] = slashId;
        slashId2SlashInfo[slashId] = slashInfo;
        _reportMachineFault(slashInfo.machineId, slashId);
        emit ReportMachineFault(slashInfo.machineId, slashId, slashPayToAddress);
    }

    function _reportMachineFault(string memory machineId, uint256 slashId) internal {
        if (!rewardStart()) {
            return;
        }

        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        tryPaySlashOnReport(stakeInfo, machineId, slashId, slashPayToAddress);

        _claim(machineId);
        _unStake(machineId, stakeInfo.holder);
    }
}
