// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909XTP} from "src/ERC6909/ERC6909XTP.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";
import {TokenPurchaseERC20} from "src/common/TokenPurchaseERC20.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with token time-to-live (TTL) and price management
 * for token purchases using ERC-20 tokens (e.g. USDC, USDT).
 */
contract EVMAuth6909TP20 is ERC6909XTP, TokenPurchaseERC20 {
    /**
     * @dev Initializes the contract with an initial delay, default admin address, URI, and initial
     * treasury address for payment collection.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The base URI for token metadata.
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_, address payable initialTreasury)
        ERC6909XTP(initialDelay, initialDefaultAdmin, uri_, initialTreasury)
    {}

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
