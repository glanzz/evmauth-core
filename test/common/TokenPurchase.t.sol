// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenPurchase } from "src/common/TokenPurchase.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenPurchase is TokenPurchase, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address payable initialTreasury) public initializer {
        __TokenPurchase_init(initialTreasury);
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenPurchase_Test is BaseTest {
    MockTokenPurchase internal token;

    address payable public treasury;

    function setUp() public virtual {
        // Set treasury address
        treasury = payable(makeAddr("treasury"));

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("MockTokenPurchase", abi.encodeCall(MockTokenPurchase.initialize, (treasury)));
        token = MockTokenPurchase(proxy);
    }
}
