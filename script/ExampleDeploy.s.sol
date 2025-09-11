// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { BaseDeploy1155, BaseDeploy6909 } from "script/BaseDeploy.s.sol";

/**
 * @dev Example deployment script for EVMAuth1155
 */
contract ExampleDeploy1155 is BaseDeploy1155 {
    /**
     * @dev Main deployment function. Sets initializer parameters, then executes the deployment.
     */
    function run() public {
        uint48 initialDelay = 2 days; // 48-hour admin transfer delay
        address initialDefaultAdmin = msg.sender; // Deployer as initial admin
        address payable initialTreasury = payable(msg.sender); // Deployer address as initial treasury

        // Grant all roles to the deployer
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, msg.sender);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, msg.sender);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, msg.sender);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, msg.sender);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, msg.sender);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, msg.sender);

        // Example token URI with {id} placeholder, per ERC-1155 metadata standard
        string memory uri = "https://token-cdn-domain/{id}.json";

        // Execute the deployment
        deploy(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, uri);
    }
}

/**
 * @dev Example deployment script for EVMAuth6909
 */
contract ExampleDeploy6909 is BaseDeploy6909 {
    /**
     * @dev Main deployment function. Sets initializer parameters, then executes the deployment.
     */
    function run() public {
        uint48 initialDelay = 2 days; // 48-hour admin transfer delay
        address initialDefaultAdmin = msg.sender; // Deployer as initial admin
        address payable initialTreasury = payable(msg.sender); // Deployer address as initial treasury

        // Grant all roles to the deployer
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, msg.sender);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, msg.sender);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, msg.sender);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, msg.sender);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, msg.sender);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, msg.sender);

        // Example contract URI, per EIP-6909 content URI extension
        string memory uri = "https://token-cdn-domain/contract-metadata.json";

        // Execute the deployment
        deploy(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, uri);
    }
}
