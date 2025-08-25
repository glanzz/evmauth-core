// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenPrice } from "src/common/TokenPrice.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @dev Mixin for token contracts that adds support for direct purchase using native currency (e.g., ETH, MATIC).
 * This contract extends {TokenPrice} to include price management and treasury handling.
 */
abstract contract TokenPurchase is TokenPrice, PausableUpgradeable {
    /**
     * @dev Error thrown when the payment made for a purchase is insufficient.
     */
    error TokenPurchaseInsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPurchase_init(address payable initialTreasury) public onlyInitializing {
        __TokenPrice_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenPurchase_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * using native currency. The caller must send sufficient payment with the transaction.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {Purchase} event where the `caller` and `receiver` are the same.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment sent with the transaction must be sufficient to cover the total price for the `amount` of tokens.
     *
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function purchase(uint256 id, uint256 amount) external payable virtual whenNotPaused nonReentrant {
        _purchaseFor(_msgSender(), id, amount);
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * for a designated `receiver` using native currency. The caller must send sufficient
     * payment with the transaction.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment sent with the transaction must be sufficient to cover the total price for the `amount` of tokens.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function purchaseFor(address receiver, uint256 id, uint256 amount)
        external
        payable
        virtual
        whenNotPaused
        nonReentrant
    {
        _purchaseFor(receiver, id, amount);
    }

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
}
