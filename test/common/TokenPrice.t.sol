// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenPrice is TokenPrice, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address payable initialTreasury) public initializer {
        __TokenPrice_init(initialTreasury);
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenPrice_Test is BaseTest {
    MockTokenPrice internal token;

    address payable public treasury;

    function setUp() public virtual {
        // Set treasury address
        treasury = payable(makeAddr("treasury"));

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("MockTokenPrice", abi.encodeCall(MockTokenPrice.initialize, (treasury)));
        token = MockTokenPrice(proxy);
    }
}
