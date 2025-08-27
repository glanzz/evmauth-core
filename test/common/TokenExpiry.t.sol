// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenExpiry } from "src/common/TokenExpiry.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenExpiry is TokenExpiry, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __TokenExpiry_init();
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenExpiry_Test is BaseTest {
    MockTokenExpiry internal token;

    function setUp() public virtual override {
        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("TokenExpiry.t.sol:MockTokenExpiry", abi.encodeCall(MockTokenExpiry.initialize, ()));
        token = MockTokenExpiry(proxy);
    }
}
