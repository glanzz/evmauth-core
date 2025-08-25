// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenTTL } from "src/common/TokenTTL.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenTTL is TokenTTL, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __TokenTTL_init();
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenTTL_Test is BaseTest {
    MockTokenTTL internal token;

    function setUp() public virtual {
        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("MockTokenTTL", abi.encodeCall(MockTokenTTL.initialize, ()));
        token = MockTokenTTL(proxy);
    }
}
