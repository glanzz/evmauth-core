// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";
import {TokenPurchaseERC20} from "src/common/TokenPurchaseERC20.sol";

contract MockTokenPurchaseERC20 is TokenPurchaseERC20, TokenPrice {
    constructor(address payable initialTreasury) TokenPrice(initialTreasury) {}

    // @inheritdoc TokenPrice
    function _validatePurchase(address receiver, uint256 id, uint256 amount)
        internal
        view
        override(TokenPrice, TokenPurchaseERC20)
        returns (uint256)
    {
        return TokenPrice._validatePurchase(receiver, id, amount);
    }

    // @inheritdoc TokenPrice
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice)
        internal
        override(TokenPrice, TokenPurchaseERC20)
    {
        TokenPrice._completePurchase(receiver, id, amount, totalPrice);
    }

    // @inheritdoc TokenPrice
    function _getTreasury() internal view override(TokenPrice, TokenPurchaseERC20) returns (address payable) {
        return TokenPrice._getTreasury();
    }
}

contract TokenPurchaseERC20_Test is Test {
    MockTokenPurchaseERC20 internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));
        token = new MockTokenPurchaseERC20(treasury);
    }
}
