// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenConfiguration } from "src/common/TokenConfiguration.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @dev Mock contract for testing {TokenConfiguration}.
 */
contract MockTokenConfiguration is TokenConfiguration, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __TokenConfiguration_init();
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

/**
 * @dev Test contract for {TokenConfiguration}.
 */
contract TokenConfigurationTest is BaseTest {
    MockTokenConfiguration internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenConfiguration());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "TokenConfiguration.t.sol:MockTokenConfiguration";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenConfiguration.initialize, (owner));
    }

    function _setToken(address proxyAddress) internal override {
        token = MockTokenConfiguration(proxyAddress);
    }

    // ============ Unit Tests ============ //
}
