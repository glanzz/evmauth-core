// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909XP} from "src/ERC6909/ERC6909XP.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";
import {TokenPurchase} from "src/common/TokenPurchase.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with price management for token purchases
 * with native currency.
 */
contract EVMAuth6909P is ERC6909XP, TokenPurchase {
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
        ERC6909XP(initialDelay, initialDefaultAdmin, uri_, initialTreasury)
    {}

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
