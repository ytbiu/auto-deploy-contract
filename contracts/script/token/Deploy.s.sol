// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Token} from "../../src/token/Token.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {console} from "forge-std/Test.sol";

contract Deploy is Script {
    function run() external returns (address proxy, address logic) {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;

        if (
            bytes(privateKeyString).length > 0 && bytes(privateKeyString)[0] == "0" && bytes(privateKeyString)[1] == "x"
        ) {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        } else {
            deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        }

        vm.startBroadcast(deployerPrivateKey);

        (proxy, logic) = deploy();
        vm.stopBroadcast();
        console.log("Proxy Contract deployed at:", proxy);
        console.log("Logic Contract deployed at:", logic);
        return (proxy, logic);
    }

    function deploy() public returns (address proxy, address logic) {
        Options memory opts;

        logic = Upgrades.deployImplementation("NFTStaking.sol:NFTStaking", opts);

        address tokenOwner = vm.envAddress("TOKEN_OWNER");
        console.log("owner Address:", tokenOwner);

        string memory tokenName = vm.envString("TOKEN_NAME");
        console.log(" token name:", tokenName);

        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");
        console.log("token symbol:", tokenSymbol);

        uint256 initSupply = uint256(vm.envInt("TOKEN_INIT_SUPPLY"));
        console.log("initSupply:", initSupply);

        uint256 supplyFixedYears = uint256(vm.envInt("TOKEN_SUPPLY_FIXED_YEARS"));
        console.log("supplyFixedYears:", supplyFixedYears);

        uint256 amountCanMintPerYear = uint256(vm.envInt("TOKEN_AMOUNT_CAN_MINT_PER_YEAR"));
        console.log("after fixed year, can mint amount per year :", amountCanMintPerYear);

        address iaoContractAddress = vm.envAddress("IAO_CONTRACT_ADDRESS");
        console.log("iaoContractAddress :", iaoContractAddress);

        uint256 amountToIAO = uint256(vm.envInt("AMOUNT_TO_IAO"));
        console.log("amountToIAO :", amountToIAO);

        proxy = Upgrades.deployUUPSProxy(
            "Token.sol:Token",
            abi.encodeCall(
                Token.initialize,
                (
                    tokenOwner,
                    tokenName,
                    tokenSymbol,
                    initSupply,
                    supplyFixedYears,
                    amountCanMintPerYear,
                    iaoContractAddress,
                    amountToIAO
                )
            )
        );
        return (proxy, logic);
    }
}
