// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { EVMAuth } from "src/base/EVMAuth.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { EVMAuth6909 } from "src/EVMAuth6909.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "forge-std/console.sol";

/**
 * @dev Base deployment script for upgradeable EVMAuth contracts
 */
abstract contract BaseDeploy is Script {
    // Deployed proxy contract address
    address public proxy;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant UPGRADE_MANAGER_ROLE = keccak256("UPGRADE_MANAGER_ROLE");
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Main deployment function with logging. Call this from `run()` in the derived contract.
     * @param initialDelay The initial admin delay for the contract
     * @param initialDefaultAdmin The initial default admin address
     * @param initialTreasury The initial treasury address for payments
     * @param roleGrants Array of initial role grants
     * @param uri The base token (ERC-1155) or contract (ERC-6909) URI
     */
    function deploy(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) public {
        bytes memory initData =
            _getInitializeCallData(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, uri);

        vm.startBroadcast();
        proxy = Upgrades.deployUUPSProxy(_getDeploymentArtifact(), initData);
        _postDeploy(proxy);
        vm.stopBroadcast();

        console.log("EVMAuth deployed to:", proxy);
        console.log("Default Admin:", initialDefaultAdmin);
        console.log("Treasury:", initialTreasury);
        for (uint256 i = 0; i < roleGrants.length; i++) {
            console.log(string.concat("Granted role ", _roleName(roleGrants[i].role), " to:"), roleGrants[i].account);
        }
        console.log("URI:", uri);
    }

    /**
     * @dev Helper to convert role bytes32 to string for logging
     * @param role The role as bytes32
     * @return The role name as string
     */
    function _roleName(bytes32 role) internal pure returns (string memory) {
        if (role == DEFAULT_ADMIN_ROLE) return "DEFAULT_ADMIN_ROLE";
        if (role == UPGRADE_MANAGER_ROLE) return "UPGRADE_MANAGER_ROLE";
        if (role == ACCESS_MANAGER_ROLE) return "ACCESS_MANAGER_ROLE";
        if (role == TOKEN_MANAGER_ROLE) return "TOKEN_MANAGER_ROLE";
        if (role == MINTER_ROLE) return "MINTER_ROLE";
        if (role == BURNER_ROLE) return "BURNER_ROLE";
        if (role == TREASURER_ROLE) return "TREASURER_ROLE";
        return "UNKNOWN_ROLE";
    }

    // ========== Abstract Methods ==========

    /**
     * @dev Get the implementation contract name for deployment
     * @return The contract name string
     */
    function _getDeploymentArtifact() internal pure virtual returns (string memory);

    /**
     * @dev Get the initialization calldata for the proxy
     * @param initialDelay The initial admin delay for the contract
     * @param initialDefaultAdmin The initial default admin address
     * @param initialTreasury The initial treasury address for payments
     * @param roleGrants Array of initial role grants
     * @param uri The base token (ERC-1155) or contract (ERC-6909) URI
     * @return The encoded initialization calldata
     */
    function _getInitializeCallData(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) internal view virtual returns (bytes memory);

    /**
     * @dev Optional post-deployment setup (e.g., granting additional roles)
     * @param proxyAddress The address of the deployed proxy contract
     */
    function _postDeploy(address proxyAddress) internal virtual { }
}

/**
 * @dev Base deploy script for EVMAuth1155
 */
abstract contract BaseDeploy1155 is BaseDeploy {
    /// @inheritdoc BaseDeploy
    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth1155.sol:EVMAuth1155";
    }

    /// @inheritdoc BaseDeploy
    function _getInitializeCallData(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(
            EVMAuth1155.initialize, (initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, uri)
        );
    }
}

/**
 * @dev Base deploy script for EVMAuth6909
 */
abstract contract BaseDeploy6909 is BaseDeploy {
    /// @inheritdoc BaseDeploy
    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth6909.sol:EVMAuth6909";
    }

    /// @inheritdoc BaseDeploy
    function _getInitializeCallData(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(
            EVMAuth6909.initialize, (initialDelay, initialDefaultAdmin, initialTreasury, roleGrants, uri)
        );
    }
}
