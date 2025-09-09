// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { EVMAuth6909 } from "src/EVMAuth6909.sol";
import "forge-std/console.sol";

/**
 * @dev Upgrade script for EVMAuth1155
 */
contract Upgrade1155 is Script {
    function run() external {
        // Get proxy address from env
        address proxyAddress = vm.envAddress("PROXY");

        vm.startBroadcast();

        // Deploy new implementation
        EVMAuth1155 newImplementation = new EVMAuth1155();

        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Upgrading proxy at:", proxyAddress);

        // Get proxy instance
        EVMAuth1155 proxy = EVMAuth1155(proxyAddress);

        // Upgrade (caller must have UPGRADE_MANAGER_ROLE)
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("Upgrade complete!");

        vm.stopBroadcast();
    }
}

/**
 * @dev Upgrade script for EVMAuth6909
 */
contract Upgrade6909 is Script {
    function run() external {
        // Get proxy address from env
        address proxyAddress = vm.envAddress("PROXY");

        vm.startBroadcast();

        // Deploy new implementation
        EVMAuth6909 newImplementation = new EVMAuth6909();

        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Upgrading proxy at:", proxyAddress);

        // Get proxy instance
        EVMAuth6909 proxy = EVMAuth6909(proxyAddress);

        // Upgrade (caller must have UPGRADE_MANAGER_ROLE)
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("Upgrade complete!");

        vm.stopBroadcast();
    }
}
