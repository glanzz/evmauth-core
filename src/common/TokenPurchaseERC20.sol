// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract that supports the direct purchase of tokens
 * using ERC-20 tokens (e.g. USDC, USDT).
 *
 * This is a mixin contract that expects the following functions to be available:
 * - _validatePurchase(address, uint256, uint256) returns (uint256)
 * - _completePurchase(address, uint256, uint256, uint256)
 * - _getTreasury() returns (address payable)
 * - supportsInterface(bytes4) returns (bool)
 */
abstract contract TokenPurchaseERC20 is Pausable {
    // Import SafeERC20 to revert if a transfer returns false
    using SafeERC20 for IERC20;

    /**
     * @dev Mapping to track ERC-20 token contract addresses accepted for purchases.
     * This mapping allows for quick checks to see if a token is accepted.
     */
    mapping(address => bool) private _paymentTokens;

    /**
     * @dev List of all accepted ERC-20 token addresses for purchases.
     * This is used to return the list of accepted tokens.
     */
    address[] private _paymentTokensList;

    /**
     * @dev Emitted when a accepted ERC-20 token is added to the list of payment tokens.
     */
    event TokenPurchaseERC20PaymentTokenAdded(address indexed token);

    /**
     * @dev Emitted when a accepted ERC-20 token is removed from the list of payment tokens.
     */
    event TokenPurchaseERC20PaymentTokenRemoved(address indexed token);

    /**
     * @dev Error thrown when the payer has insufficient allowance for the ERC-20 token payment.
     */
    error TokenPurchaseERC20InsufficientAllowance(address token, uint256 required, uint256 allowance);

    /**
     * @dev Error thrown when the payer has insufficient balance of the ERC-20 token for the payment.
     */
    error TokenPurchaseERC20InsufficientBalance(address token, uint256 required, uint256 balance);

    /**
     * @dev Error thrown when the ERC-20 token being used for payment is not accepted.
     */
    error TokenPurchaseERC20InvalidPaymentToken(address token);

    /**
     * @dev Returns the list of all accepted ERC-20 tokens for purchases.
     *
     * @return An array of addresses of accepted ERC-20 tokens
     */
    function acceptedERC20PaymentTokens() external view virtual returns (address[] memory) {
        return _paymentTokensList;
    }

    /**
     * @dev Returns whether a specific ERC-20 token is accepted for purchases.
     *
     * @param token The address of the ERC-20 token to check
     * @return True if the token is accepted, false otherwise
     */
    function isERC20PaymentTokenAccepted(address token) external view virtual returns (bool) {
        return _paymentTokens[token];
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
     * It validates the purchase, transfers ERC-20 tokens from sender to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment token must be in the list of accepted ERC-20 tokens.
     * - The sender must have approved this contract to transfer the required amount of ERC-20 tokens.
     * - The sender must have sufficient balance of the ERC-20 token.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseFor(address receiver, address paymentToken, uint256 id, uint256 amount) internal virtual {
        if (!_paymentTokens[paymentToken]) {
            revert TokenPurchaseERC20InvalidPaymentToken(paymentToken);
        }

        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        IERC20 token = IERC20(paymentToken);

        // Check allowance
        uint256 allowance = token.allowance(_msgSender(), address(this));
        if (allowance < totalPrice) {
            revert TokenPurchaseERC20InsufficientAllowance(paymentToken, totalPrice, allowance);
        }

        // Check balance
        uint256 balance = token.balanceOf(_msgSender());
        if (balance < totalPrice) {
            revert TokenPurchaseERC20InsufficientBalance(paymentToken, totalPrice, balance);
        }

        // Transfer ERC-20 tokens from sender to treasury
        token.safeTransferFrom(_msgSender(), _getTreasury(), totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Adds an ERC-20 token to the list of accepted payment tokens.
     * @param token The address of the ERC-20 token to add.
     */
    function _addERC20PaymentToken(address token) internal virtual {
        if (token == address(0)) {
            revert TokenPurchaseERC20InvalidPaymentToken(token);
        }
        if (!_paymentTokens[token]) {
            _paymentTokens[token] = true;
            _paymentTokensList.push(token);
            emit TokenPurchaseERC20PaymentTokenAdded(token);
        }
    }

    /**
     * @dev Removes an ERC-20 token from the list of accepted payment tokens.
     * @param token The address of the ERC-20 token to remove.
     */
    function _removeERC20PaymentToken(address token) internal virtual {
        if (_paymentTokens[token]) {
            _paymentTokens[token] = false;

            // Remove from array
            for (uint256 i = 0; i < _paymentTokensList.length; i++) {
                if (_paymentTokensList[i] == token) {
                    // Move last element to this position and pop
                    _paymentTokensList[i] = _paymentTokensList[_paymentTokensList.length - 1];
                    _paymentTokensList.pop();
                    break;
                }
            }

            emit TokenPurchaseERC20PaymentTokenRemoved(token);
        }
    }

    function _validatePurchase(address receiver, uint256 id, uint256 amount) internal virtual returns (uint256);
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal virtual;
    function _getTreasury() internal view virtual returns (address payable);
}
