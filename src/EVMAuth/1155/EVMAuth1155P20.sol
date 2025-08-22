// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155XP} from "src/ERC1155/ERC1155XP.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";
import {TokenPurchaseERC20} from "src/common/TokenPurchaseERC20.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with price management and token purchases
 * using ERC-20 tokens (e.g. USDC, USDT).
 */
contract EVMAuth1155P20 is ERC1155XP, TokenPurchaseERC20 {
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
        ERC1155XP(initialDelay, initialDefaultAdmin, uri_, initialTreasury)
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
