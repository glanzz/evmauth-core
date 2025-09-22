// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { BaseDeploy1155, BaseDeploy6909 } from "script/BaseDeploy.s.sol";

abstract contract Deploy {
    uint48 public initialDelay = 2 days; // 48-hour admin transfer delay
    address public initialDefaultAdmin = address(0);
    address payable public initialTreasury = payable(address(0));
    address public upgradeManager = address(0);
    address public accessManager = address(0);
    address public tokenManager = address(0);
    address public minter = address(0);
    address public burner = address(0);
    address public treasurer = address(0);

    function setUp() public virtual {
        if (initialDefaultAdmin == address(0)) initialDefaultAdmin = msg.sender;
        if (initialTreasury == payable(address(0))) initialTreasury = payable(msg.sender);
        if (upgradeManager == address(0)) upgradeManager = msg.sender;
        if (accessManager == address(0)) accessManager = msg.sender;
        if (tokenManager == address(0)) tokenManager = msg.sender;
        if (minter == address(0)) minter = msg.sender;
        if (burner == address(0)) burner = msg.sender;
        if (treasurer == address(0)) treasurer = msg.sender;
    }
}

/**
 * @dev Deployment script for EVMAuth1155
 */
contract Deploy1155 is BaseDeploy1155, Deploy {
    /**
     * @dev Main deployment function. Sets initializer parameters, then executes the deployment.
     */
    function run() public {
        setUp();

        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, upgradeManager);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        deploy(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, "");
    }
}

/**
 * @dev Deployment script for EVMAuth6909
 */
contract Deploy6909 is BaseDeploy6909, Deploy {
    /**
     * @dev Main deployment function. Sets initializer parameters, then executes the deployment.
     */
    function run() public {
        setUp();

        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, upgradeManager);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        deploy(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, "");
    }
}
