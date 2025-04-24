// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {XAAIAO} from "../../src/iao/XAAIAO.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/Test.sol";

contract Deploy is Script {
    // 主入口函数（保持兼容性）
    function run() external returns (address proxy, address logic) {
        // 保留原始环境变量加载方式
        return runWithParams(
            vm.envBytes32("PRIVATE_KEY"),
            vm.envAddress("XAAIAO_OWNER"),
            vm.envAddress("XAAIAO_TOKEN_IN_CONTRACT"),
            vm.envAddress("XAAIAO_REWARD_TOKEN_CONTRACT"),
            vm.envInt("XAAIAO_START_TIMESTAMP"),
            vm.envInt("XAAIAO_PERIOD_HOURS"),
            vm.envInt("XAAIAO_REWARD_AMOUNT"),
            vm.envAddress("XAAIAO_NFT_HOLDER_CONTRACT")
        );
    }

    // 新参数化入口函数
    function runWithParams(
        bytes32 privateKeyBytes, // 私钥（bytes32格式）
        address owner, // 所有者地址
        address tokenInContract, // 输入代币合约
        address rewardTokenContract, // 奖励代币合约
        int256 startTimestamp, // 开始时间戳
        int256 periodHours, // 周期小时数
        int256 rewardAmount, // 奖励数量
        address nftHolderContract // NFT持有者合约
    ) public returns (address proxy, address logic) {
        uint256 deployerPrivateKey = _parsePrivateKey(privateKeyBytes);

        vm.startBroadcast(deployerPrivateKey);
        (proxy, logic) = deploy(
            owner, tokenInContract, rewardTokenContract, startTimestamp, periodHours, rewardAmount, nftHolderContract
        );
        vm.stopBroadcast();

        console.log("Proxy Contract deployed at:", proxy);
        console.log("Logic Contract deployed at:", logic);
        return (proxy, logic);
    }

    // 私钥解析逻辑
    function _parsePrivateKey(bytes32 privateKeyBytes) internal pure returns (uint256) {
        // 处理带0x前缀的hex格式
        if (privateKeyBytes[0] == "0" && privateKeyBytes[1] == "x") {
            return uint256(bytes32(abi.encodePacked(privateKeyBytes)));
        }
        return uint256(privateKeyBytes);
    }

    // 参数化部署函数
    function deploy(
        address owner,
        address tokenInContract,
        address rewardTokenContract,
        int256 startTimestamp,
        int256 periodHours,
        int256 rewardAmount,
        address nftHolderContract
    ) public returns (address proxy, address logic) {
        console.log("Owner Address:", owner);
        console.log("TokenIn Contract Address:", tokenInContract);
        console.log("RewardToken Contract Address:", rewardTokenContract);
        console.log("Start Timestamp:", startTimestamp);
        console.log("Period Hours:", periodHours);
        console.log("Reward Amount:", rewardAmount);
        console.log("NFT Holder Contract:", nftHolderContract);

        proxy = Upgrades.deployUUPSProxy(
            "XAAIAO.sol:XAAIAO",
            abi.encodeCall(
                XAAIAO.initialize,
                (
                    owner,
                    tokenInContract,
                    rewardTokenContract,
                    uint256(startTimestamp),
                    uint256(periodHours),
                    uint256(rewardAmount),
                    nftHolderContract
                )
            )
        );
        return (proxy, logic);
    }
}
