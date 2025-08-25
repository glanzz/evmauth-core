// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenNonTransferable } from "src/common/TokenNonTransferable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenNonTransferable is TokenNonTransferable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenNonTransferable_Test is BaseTest {
    MockTokenNonTransferable internal token;

    function setUp() public virtual {
        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("MockTokenNonTransferable", abi.encodeCall(MockTokenNonTransferable.initialize, ()));
        token = MockTokenNonTransferable(proxy);
    }
}
