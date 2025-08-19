// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155Price} from "./IERC1155Price.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract that supports the direct purchase of tokens
 * using ERC-20 tokens (e.g. USDC, USDT).
 */
interface IERC1155PurchaseWithERC20 is IERC1155Price {
    /**
     * @dev Emitted when a accepted ERC-20 token is added to the list of payment tokens.
     */
    event ERC20PaymentTokenAdded(address indexed token);

    /**
     * @dev Emitted when a accepted ERC-20 token is removed from the list of payment tokens.
     */
    event ERC20PaymentTokenRemoved(address indexed token);

    /**
     * @dev Purchases `amount` tokens of type `id` using a specific ERC-20 token as payment.
     * The payment is made from the caller's address.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {Purchase} event where the `caller` is the same as the `receiver`.
     *
     * Reverts if the payment token is not accepted or if the caller has insufficient balance or allowance.
     *
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return bool indicating whether the purchase was successful.
     */
    function purchaseWithERC20(address paymentToken, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev Purchases `amount` tokens of type `id` using a specific ERC-20 token as payment for a specific `receiver`.
     * The payment is made from the caller's address.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Reverts if the payment token is not accepted or if the caller has insufficient balance or allowance.
     *
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return bool indicating whether the purchase was successful.
     */
    function purchaseWithERC20For(address paymentToken, address receiver, uint256 id, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the list of all accepted ERC-20 tokens for purchases.
     *
     * @return An array of addresses of accepted ERC-20 tokens
     */
    function acceptedERC20PaymentTokens() external view returns (address[] memory);

    /**
     * @dev Returns whether a specific ERC-20 token is accepted for purchases.
     *
     * @param token The address of the ERC-20 token to check
     * @return True if the token is accepted, false otherwise
     */
    function isERC20PaymentTokenAccepted(address token) external view returns (bool);
}