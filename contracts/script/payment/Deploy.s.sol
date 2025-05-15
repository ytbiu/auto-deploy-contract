// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Payment} from "../../src/payment/Payment.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {console} from "forge-std/Test.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

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
        logic = Upgrades.deployImplementation("Payment.sol:Payment", opts);

        address owner = vm.envAddress("OWNER");
        console.log("owner:", owner);

        address paymentToken = vm.envAddress("PAYMENT_TOKEN");
        console.log("paymentToken:", paymentToken);

        uint256 freeRequestCount = uint256(vm.envUint("FREE_REQUEST_COUNT"));
        console.log("freeRequestCount:", freeRequestCount);

        uint256 addressFreeRequestCount = uint256(vm.envUint("ADDRESS_FREE_REQUEST_COUNT"));
        console.log("addressFreeRequestCount:", addressFreeRequestCount);

        uint256 minUSDBalanceInUSDForUsingFreeRequest = uint256(vm.envUint("MIN_USD_BALANCE_FOR_USING_FREE_REQUEST"));
        console.log("minUSDBalanceForUsingFreeRequest:", minUSDBalanceInUSDForUsingFreeRequest);

        uint256 vipMonthlyQuotas = uint256(vm.envUint("VIP_MONTHLY_QUOTAS"));
        console.log("vipMonthlyQuotas:", vipMonthlyQuotas);

        uint256 vipPriceFixedCount = uint256(vm.envUint("VIP_PRICE_FIXED_COUNT"));
        console.log("vipPriceFixedCount:", vipPriceFixedCount);

        uint256 vipPriceMonthly = uint256(vm.envUint("VIP_PRICE_MONTHLY"));
        console.log("vipPriceMonthly:", vipPriceMonthly);

        proxy = Upgrades.deployUUPSProxy(
            "Payment.sol:Payment",
            abi.encodeCall(
                Payment.initialize,
                (
                    owner,
                    paymentToken,
                    freeRequestCount,
                    addressFreeRequestCount,
                    minUSDBalanceInUSDForUsingFreeRequest,
                    vipMonthlyQuotas,
                    vipPriceFixedCount,
                    vipPriceMonthly
                )
            )
        );
        return (proxy, logic);
    }
}
