// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { EVMAuth6909 } from "src/EVMAuth6909.sol";
import { BaseTestWithAccessControlAndERC20s } from "test/_helpers/BaseTest.sol";

contract EVMAuth6909Test is BaseTestWithAccessControlAndERC20s {
    EVMAuth6909 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new EVMAuth6909());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth6909.sol:EVMAuth6909";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, owner);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        return abi.encodeCall(
            EVMAuth6909.initialize,
            (2 days, owner, treasury, roleGrants, "https://contract-cdn-domain/contract-metadata.json")
        );
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = EVMAuth6909(proxyAddress);
    }

    function _grantRoles() internal override {
        // Roles are granted during initialization
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertEq(v1.nextTokenID(), 1);

        assertTrue(v1.hasRole(v1.UPGRADE_MANAGER_ROLE(), owner), "Upgrade manager role not set correctly");
        assertTrue(v1.hasRole(v1.ACCESS_MANAGER_ROLE(), accessManager), "Access manager role not set correctly");
        assertTrue(v1.hasRole(v1.TOKEN_MANAGER_ROLE(), tokenManager), "Token manager role not set correctly");
        assertTrue(v1.hasRole(v1.MINTER_ROLE(), minter), "Minter role not set correctly");
        assertTrue(v1.hasRole(v1.BURNER_ROLE(), burner), "Burner role not set correctly");
        assertTrue(v1.hasRole(v1.TREASURER_ROLE(), treasurer), "Treasurer role not set correctly");
    }
}
