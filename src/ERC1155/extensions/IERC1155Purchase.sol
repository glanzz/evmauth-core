// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155Price} from "./IERC1155Price.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract that supports the direct purchase of tokens
 * using the native currency (i.e. ETH).
 */
interface IERC1155Purchase is IERC1155Price {
    /**
     * @dev Purchases `amount` tokens of type `id` for the caller.
     * The payment is made in the native currency, and the tokens are minted to the caller's address.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {Purchase} event where the `caller` is the same as the `receiver`.
     *
     * Requirements:
     * - The `amount` must be greater than zero.
     * - The `id` must have a set price.
     * - The caller must send enough native currency to cover the purchase.
     * - The contract must have a valid price set for the `id`.
     *
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return bool indicating whether the purchase was successful.
     */
    function purchase(uint256 id, uint256 amount) external payable returns (bool);

    /**
     * @dev Purchases `amount` tokens of type `id` for a specific `receiver`.
     * The payment is made in the native currency, and the tokens are minted to the `receiver`'s address.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The `receiver` address must not be zero.
     * - The `amount` must be greater than zero.
     * - The `id` must have a set price.
     * - The caller must send enough native currency to cover the purchase.
     * - The contract must have a valid price set for the `id`.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return bool indicating whether the purchase was successful.
     */
    function purchaseFor(address receiver, uint256 id, uint256 amount) external payable returns (bool);
}