// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { TokenPurchaseERC20 } from "src/common/TokenPurchaseERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTokenPurchaseERC20 is TokenPurchaseERC20, OwnableUpgradeable, UUPSUpgradeable {
    event MintPurchasedTokensCalled(address to, uint256 id, uint256 amount);

    function initialize(address payable initialTreasury) public initializer {
        __TokenPurchaseERC20_init(initialTreasury);
        __Ownable_init(_msgSender());
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }

    /// @inheritdoc TokenPrice
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        emit MintPurchasedTokensCalled(to, id, amount);
    }
}

contract TokenPurchaseERC20_Test is BaseTest {
    MockTokenPurchaseERC20 internal token;

    address payable public treasury;

    function setUp() public virtual {
        // Set treasury address
        treasury = payable(makeAddr("treasury"));

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy("MockTokenPurchaseERC20", abi.encodeCall(MockTokenPurchaseERC20.initialize, (treasury)));
        token = MockTokenPurchaseERC20(proxy);
    }
}
