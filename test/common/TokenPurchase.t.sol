// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";
import {TokenPurchase} from "src/common/TokenPurchase.sol";

contract MockTokenPurchase is TokenPurchase, TokenPrice {
    constructor(address payable initialTreasury) TokenPrice(initialTreasury) {}

    // @inheritdoc TokenPrice
    function _validatePurchase(address receiver, uint256 id, uint256 amount)
        internal
        view
        override(TokenPrice, TokenPurchase)
        returns (uint256)
    {
        return TokenPrice._validatePurchase(receiver, id, amount);
    }

    // @inheritdoc TokenPrice
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice)
        internal
        override(TokenPrice, TokenPurchase)
    {
        TokenPrice._completePurchase(receiver, id, amount, totalPrice);
    }

    // @inheritdoc TokenPrice
    function _getTreasury() internal view override(TokenPrice, TokenPurchase) returns (address payable) {
        return TokenPrice._getTreasury();
    }
}

contract TokenPurchase_Test is Test {
    MockTokenPurchase internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));
        token = new MockTokenPurchase(treasury);
    }
}
