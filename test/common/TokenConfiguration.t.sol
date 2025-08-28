// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { BaseUpgradeTest } from "test/BaseUpgradeTest.sol";
import { TokenConfiguration } from "src/common/TokenConfiguration.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract MockTokenConfiguration is TokenConfiguration, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address initialOwner) public initializer {
        __TokenConfiguration_init();
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenConfiguration_Test is BaseTest {
    MockTokenConfiguration internal token;

    function setUp() public virtual override {
        super.setUp();

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "TokenConfiguration.t.sol:MockTokenConfiguration",
            abi.encodeCall(MockTokenConfiguration.initialize, (owner))
        );
        token = MockTokenConfiguration(proxy);
    }
}

contract TokenConfiguration_UpgradeTest is BaseUpgradeTest {
    MockTokenConfiguration internal token;

    function setToken(address proxyAddress) internal override {
        token = MockTokenConfiguration(proxyAddress);
    }

    function deployNewImplementation() internal override returns (address) {
        return address(new MockTokenConfiguration());
    }

    function getContractName() internal pure override returns (string memory) {
        return "TokenConfiguration.t.sol:MockTokenConfiguration";
    }

    function getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenConfiguration.initialize, (owner));
    }
}
