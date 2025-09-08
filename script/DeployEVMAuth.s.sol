// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
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

    /**
     * @dev Main deployment function
     * @param defaultAdmin The initial default admin address
     * @param treasury The treasury address for payments
     */
    function deploy(address defaultAdmin, address payable treasury, string memory uri) public returns (address) {
        require(defaultAdmin != address(0), "Invalid admin address");
        require(treasury != address(0), "Invalid treasury address");

        bytes memory initData = _getInitializeCallData(defaultAdmin, treasury, uri);
        proxy = Upgrades.deployUUPSProxy(_getDeploymentArtifact(), initData);

        _postDeploy(proxy);

        return proxy;
    }

    // ========== Abstract Methods ==========

    /**
     * @dev Get the implementation contract name for deployment
     */
    function _getDeploymentArtifact() internal pure virtual returns (string memory);

    /**
     * @dev Get the initialization calldata for the proxy
     */
    function _getInitializeCallData(address defaultAdmin, address payable treasury, string memory uri)
        internal
        view
        virtual
        returns (bytes memory);

    /**
     * @dev Optional post-deployment setup (e.g., granting additional roles)
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

        vm.startBroadcast();
        address deployed = deploy(defaultAdmin, treasury, uri);
        vm.stopBroadcast();

        evmAuth = EVMAuth1155(deployed);

        console.log("EVMAuth1155 deployed to:", deployed);
        console.log("Default Admin:", defaultAdmin);
        console.log("Treasury:", treasury);
        console.log("Token URI:", uri);
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth1155.sol:EVMAuth1155";
    }

    function _getInitializeCallData(address defaultAdmin, address payable treasury, string memory uri)
        internal
        view
        override
        returns (bytes memory)
    {
        return abi.encodeCall(EVMAuth1155.initialize, (ADMIN_DELAY, defaultAdmin, treasury, uri));
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

        vm.startBroadcast();
        address deployed = deploy(defaultAdmin, treasury, uri);
        vm.stopBroadcast();

        evmAuth = EVMAuth6909(deployed);

        console.log("EVMAuth6909 deployed to:", deployed);
        console.log("Default Admin:", defaultAdmin);
        console.log("Treasury:", treasury);
        console.log("Contract URI:", uri);
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth6909.sol:EVMAuth6909";
    }

    function _getInitializeCallData(address defaultAdmin, address payable treasury, string memory uri)
        internal
        view
        override
        returns (bytes memory)
    {
        return abi.encodeCall(EVMAuth6909.initialize, (ADMIN_DELAY, defaultAdmin, treasury, uri));
    }
}

/**
 * @dev Deploy script for multiple networks
 */
contract DeployMultiNetwork is Script {
    DeployEVMAuth1155 public deployer1155;
    DeployEVMAuth6909 public deployer6909;

    function setUp() public {
        deployer1155 = new DeployEVMAuth1155();
        deployer6909 = new DeployEVMAuth6909();
    }

    function run() public {
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN_ADDRESS", msg.sender);
        address payable treasury = payable(vm.envOr("TREASURY_ADDRESS", msg.sender));
        bool use1155 = vm.envOr("ERC_1155", false);
        bool use6909 = vm.envOr("ERC_6909", false);
        string memory uri = use1155 ? vm.envOr("TOKEN_URI", string("")) : vm.envOr("CONTRACT_URI", string(""));

        // Ensure exactly one token standard is set to true
        require(use1155 != use6909, "Either ERC_1155 or ERC_6909 env var must be set to true");

        string[] memory networks = new string[](2);
        networks[0] = "radius-testnet";
        networks[1] = "base-sepolia";

        // Deploy to networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("Deploying to network:", network);
            vm.createSelectFork(network);

            vm.startBroadcast();
            if (use1155) {
                address radius1155 = deployer1155.deploy(defaultAdmin, treasury, uri);
                console.log(string.concat(network, " EVMAuth1155:"), radius1155);
            }
            if (use6909) {
                address radius6909 = deployer6909.deploy(defaultAdmin, treasury, uri);
                console.log(string.concat(network, " EVMAuth6909:"), radius6909);
            }
            vm.stopBroadcast();
        }
    }
}
