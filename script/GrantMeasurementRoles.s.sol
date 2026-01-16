// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title GrantMeasurementRoles
 * @notice Script to grant necessary roles for gas measurement operations
 * @dev Run with: forge script script/GrantMeasurementRoles.s.sol --rpc-url base-sepolia --broadcast --legacy
 */

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
}

contract GrantMeasurementRoles is Script {
    // Deployed contract addresses on Base Sepolia
    address constant EVMAUTH_1155 = 0x67b8dD172f50784F6eaffe27d4f79360e44367eC;
    address constant EVMAUTH_6909 = 0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539;

    // Role identifiers
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");

    function run() public {
        address measurementAddress = msg.sender;

        console.log("=================================================================");
        console.log("Granting Measurement Roles");
        console.log("=================================================================");
        console.log("Measurement Address:", measurementAddress);
        console.log("");

        vm.startBroadcast();

        // Grant roles for EVMAuth1155
        console.log("Granting roles for EVMAuth1155:", EVMAUTH_1155);
        grantRolesForContract(EVMAUTH_1155, measurementAddress);
        console.log("");

        // Grant roles for EVMAuth6909
        console.log("Granting roles for EVMAuth6909:", EVMAUTH_6909);
        grantRolesForContract(EVMAUTH_6909, measurementAddress);
        console.log("");

        vm.stopBroadcast();

        console.log("=================================================================");
        console.log("Role grants complete!");
        console.log("=================================================================");
    }

    function grantRolesForContract(address contractAddr, address measurementAddr) internal {
        IAccessControl accessControl = IAccessControl(contractAddr);

        // Grant MINTER_ROLE
        if (!accessControl.hasRole(MINTER_ROLE, measurementAddr)) {
            console.log("  Granting MINTER_ROLE...");
            accessControl.grantRole(MINTER_ROLE, measurementAddr);
        } else {
            console.log("  MINTER_ROLE already granted");
        }

        // Grant BURNER_ROLE
        if (!accessControl.hasRole(BURNER_ROLE, measurementAddr)) {
            console.log("  Granting BURNER_ROLE...");
            accessControl.grantRole(BURNER_ROLE, measurementAddr);
        } else {
            console.log("  BURNER_ROLE already granted");
        }

        // Grant PAUSER_ROLE
        if (!accessControl.hasRole(PAUSER_ROLE, measurementAddr)) {
            console.log("  Granting PAUSER_ROLE...");
            accessControl.grantRole(PAUSER_ROLE, measurementAddr);
        } else {
            console.log("  PAUSER_ROLE already granted");
        }

        // Grant ACCESS_MANAGER_ROLE
        if (!accessControl.hasRole(ACCESS_MANAGER_ROLE, measurementAddr)) {
            console.log("  Granting ACCESS_MANAGER_ROLE...");
            accessControl.grantRole(ACCESS_MANAGER_ROLE, measurementAddr);
        } else {
            console.log("  ACCESS_MANAGER_ROLE already granted");
        }

        console.log("  All roles granted!");
    }
}
