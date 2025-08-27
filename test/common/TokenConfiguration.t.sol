// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenConfiguration } from "src/common/TokenConfiguration.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenConfiguration is TokenConfiguration, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __Ownable_init(_msgSender());
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
            "TokenConfiguration.t.sol:MockTokenConfiguration", abi.encodeCall(MockTokenConfiguration.initialize, ())
        );
        token = MockTokenConfiguration(proxy);
    }
}
