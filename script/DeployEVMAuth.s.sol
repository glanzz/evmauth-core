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
abstract contract BaseDeployEVMAuth is Script {
    // Deployment parameters
    uint48 public constant ADMIN_DELAY = 2 days;

    // Deployed proxy address
    address public proxy;

    // Struct for JSON parsing
    struct RoleGrantConfig {
        string roleName;
        address account;
    }

    /**
     * @dev Main deployment function
     * @param defaultAdmin The initial default admin address
     * @param treasury The treasury address for payments
     * @param roleGrants Array of initial role grants
     * @param uri The token or contract URI
     * @return The address of the deployed proxy contract
     */
    function deploy(
        address defaultAdmin,
        address payable treasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) public returns (address) {
        require(defaultAdmin != address(0), "Invalid admin address");
        require(treasury != address(0), "Invalid treasury address");

        bytes memory initData = _getInitializeCallData(defaultAdmin, treasury, roleGrants, uri);
        proxy = Upgrades.deployUUPSProxy(_getDeploymentArtifact(), initData);

        _postDeploy(proxy);

        return proxy;
    }

    /**
     * @dev Load role grants from JSON config file (optional)
     * @param configPath Path to the JSON config file (relative to project root)
     * @return roleGrants Array of role grants, empty if file doesn't exist
     */
    function _loadRoleGrants(string memory configPath) internal view returns (EVMAuth.RoleGrant[] memory roleGrants) {
        string memory fullPath = string.concat(vm.projectRoot(), "/", configPath);

        // Check if file exists and parse
        try vm.readFile(fullPath) returns (string memory json) {
            // Parse the JSON
            bytes memory roleGrantsData = vm.parseJson(json, ".roleGrants");
            RoleGrantConfig[] memory configs = abi.decode(roleGrantsData, (RoleGrantConfig[]));

            // Convert to RoleGrant array with encoded role names
            roleGrants = new EVMAuth.RoleGrant[](configs.length);
            for (uint256 i = 0; i < configs.length; i++) {
                roleGrants[i] = EVMAuth.RoleGrant({
                    role: keccak256(abi.encodePacked(configs[i].roleName)),
                    account: configs[i].account
                });
            }

            console.log("Loaded", roleGrants.length, "role grants from config");
        } catch {
            // File doesn't exist or parsing failed - return empty array
            console.log("No role grants config found, using empty array");
            roleGrants = new EVMAuth.RoleGrant[](0);
        }
    }

    /**
     * @dev Helper function to log role grants for verification
     */
    function _logRoleGrants(EVMAuth.RoleGrant[] memory roleGrants) internal pure {
        console.log("Role Grants:");
        for (uint256 i = 0; i < roleGrants.length; i++) {
            console.log("  Role:", vm.toString(roleGrants[i].role));
            console.log("  Account:", roleGrants[i].account);
        }
    }

    // ========== Abstract Methods ==========

    /**
     * @dev Get the implementation contract name for deployment
     * @return The contract name string
     */
    function _getDeploymentArtifact() internal pure virtual returns (string memory);

    /**
     * @dev Get the initialization calldata for the proxy
     * @param defaultAdmin The initial default admin address
     * @param treasury The treasury address for payments
     * @param roleGrants Array of initial role grants
     * @param uri The token or contract URI
     * @return The encoded initialization calldata
     */
    function _getInitializeCallData(
        address defaultAdmin,
        address payable treasury,
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
 * @dev Deploy script for EVMAuth1155
 */
contract DeployEVMAuth1155 is BaseDeployEVMAuth {
    // The deployed EVMAuth1155 instance
    EVMAuth1155 public evmAuth;

    function run() public {
        // Use environment variables or set defaults
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN_ADDRESS", msg.sender);
        address payable treasury = payable(vm.envOr("TREASURY_ADDRESS", msg.sender));
        string memory uri = vm.envOr("TOKEN_URI", string(""));

        // Load role grants from config file (optional)
        string memory configPath = vm.envOr("ROLE_GRANTS_CONFIG", string("config/role-grants.json"));
        EVMAuth.RoleGrant[] memory roleGrants = _loadRoleGrants(configPath);

        vm.startBroadcast();
        address deployed = deploy(defaultAdmin, treasury, roleGrants, uri);
        vm.stopBroadcast();

        evmAuth = EVMAuth1155(deployed);

        console.log("EVMAuth1155 deployed to:", deployed);
        console.log("Default Admin:", defaultAdmin);
        console.log("Treasury:", treasury);
        console.log("Token URI:", uri);
        _logRoleGrants(roleGrants);
    }

    /// @inheritdoc BaseDeployEVMAuth
    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth1155.sol:EVMAuth1155";
    }

    /// @inheritdoc BaseDeployEVMAuth
    function _getInitializeCallData(
        address defaultAdmin,
        address payable treasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(EVMAuth1155.initialize, (ADMIN_DELAY, defaultAdmin, treasury, roleGrants, uri));
    }
}

/**
 * @dev Deploy script for EVMAuth6909
 */
contract DeployEVMAuth6909 is BaseDeployEVMAuth {
    // The deployed EVMAuth6909 instance
    EVMAuth6909 public evmAuth;

    function run() public {
        // Use environment variables or set defaults
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN_ADDRESS", msg.sender);
        address payable treasury = payable(vm.envOr("TREASURY_ADDRESS", msg.sender));
        string memory uri = vm.envOr("CONTRACT_URI", string(""));

        // Load role grants from config file (optional)
        string memory configPath = vm.envOr("ROLE_GRANTS_CONFIG", string("config/role-grants.json"));
        EVMAuth.RoleGrant[] memory roleGrants = _loadRoleGrants(configPath);

        vm.startBroadcast();
        address deployed = deploy(defaultAdmin, treasury, roleGrants, uri);
        vm.stopBroadcast();

        evmAuth = EVMAuth6909(deployed);

        console.log("EVMAuth6909 deployed to:", deployed);
        console.log("Default Admin:", defaultAdmin);
        console.log("Treasury:", treasury);
        console.log("Contract URI:", uri);
        _logRoleGrants(roleGrants);
    }

    /// @inheritdoc BaseDeployEVMAuth
    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth6909.sol:EVMAuth6909";
    }

    /// @inheritdoc BaseDeployEVMAuth
    function _getInitializeCallData(
        address defaultAdmin,
        address payable treasury,
        EVMAuth.RoleGrant[] memory roleGrants,
        string memory uri
    ) internal pure override returns (bytes memory) {
        return abi.encodeCall(EVMAuth6909.initialize, (ADMIN_DELAY, defaultAdmin, treasury, roleGrants, uri));
    }
}
