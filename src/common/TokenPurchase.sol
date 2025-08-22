// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract that supports the direct purchase of tokens
 * using native currency (i.e. ETH).
 *
 * This is a mixin contract that expects the following functions to be available:
 * - _validatePurchase(address, uint256, uint256) returns (uint256)
 * - _completePurchase(address, uint256, uint256, uint256)
 * - _getTreasury() returns (address payable)
 * - supportsInterface(bytes4) returns (bool)
 */
abstract contract TokenPurchase is Pausable {
    /**
     * @dev Error thrown when the payment made for a purchase is insufficient.
     */
    error TokenPurchaseInsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);

    /**
     * @dev Internal function to handle the purchase logic with native currency.
     * It validates the purchase, checks payment sufficiency, transfers funds to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment must be sufficient to cover the total price for the `amount` of tokens.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseFor(address receiver, uint256 id, uint256 amount) internal virtual {
        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        if (msg.value < totalPrice) {
            revert TokenPurchaseInsufficientPayment(id, amount, totalPrice, msg.value);
        }

        // Refund excess payment to the sender
        if (msg.value > totalPrice) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        }

        // Transfer payment to treasury
        _getTreasury().transfer(totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    function _validatePurchase(address receiver, uint256 id, uint256 amount) internal virtual returns (uint256);
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal virtual;
    function _getTreasury() internal view virtual returns (address payable);
}
