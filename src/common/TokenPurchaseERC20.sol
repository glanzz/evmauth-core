// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TokenPrice } from "src/common/TokenPrice.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @dev Mixin for token contracts that adds support for direct purchase using ERC-20 tokens (e.g. USDC, USDT).
 * This contract extends {TokenPrice} to include price management and treasury handling.
 */
abstract contract TokenPurchaseERC20 is TokenPrice, PausableUpgradeable {
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
    event PaymentTokenAdded(address indexed token);

    /**
     * @dev Emitted when a accepted ERC-20 token is removed from the list of payment tokens.
     */
    event PaymentTokenRemoved(address indexed token);

    /**
     * @dev Error thrown when the payer has insufficient allowance for the ERC-20 token payment.
     */
    error InsufficientERC20Allowance(address token, uint256 required, uint256 allowance);

    /**
     * @dev Error thrown when the payer has insufficient balance of the ERC-20 token for the payment.
     */
    error InsufficientERC20Balance(address token, uint256 required, uint256 balance);

    /**
     * @dev Error thrown when the ERC-20 token being used for payment is not accepted.
     */
    error InvalidERC20PaymentToken(address token);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPurchaseERC20_init(address payable initialTreasury) public onlyInitializing {
        __TokenPrice_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenPurchaseERC20_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

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
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * using the specified ERC-20 `paymentToken`. The caller must have approved
     * this contract to spend sufficient amount of the ERC-20 token.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {TokenPurchased} event where the `caller` and `receiver` are the same.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment token must be in the list of accepted ERC-20 tokens.
     * - The caller must have approved this contract to transfer the required amount of ERC-20 tokens.
     * - The caller must have sufficient balance of the ERC-20 token.
     *
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function purchase(address paymentToken, uint256 id, uint256 amount) external virtual whenNotPaused nonReentrant {
        _purchaseFor(_msgSender(), paymentToken, id, amount);
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * for a designated `receiver` using the specified ERC-20 `paymentToken`.
     * The caller must have approved this contract to spend sufficient amount
     * of the ERC-20 token.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment token must be in the list of accepted ERC-20 tokens.
     * - The caller must have approved this contract to transfer the required amount of ERC-20 tokens.
     * - The caller must have sufficient balance of the ERC-20 token.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function purchaseFor(address receiver, address paymentToken, uint256 id, uint256 amount)
        external
        virtual
        whenNotPaused
        nonReentrant
    {
        _purchaseFor(receiver, paymentToken, id, amount);
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
     * It validates the purchase, transfers ERC-20 tokens from sender to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
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
            revert InvalidERC20PaymentToken(paymentToken);
        }

        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        IERC20 token = IERC20(paymentToken);

        // Check allowance
        uint256 allowance = token.allowance(_msgSender(), address(this));
        if (allowance < totalPrice) {
            revert InsufficientERC20Allowance(paymentToken, totalPrice, allowance);
        }

        // Check balance
        uint256 balance = token.balanceOf(_msgSender());
        if (balance < totalPrice) {
            revert InsufficientERC20Balance(paymentToken, totalPrice, balance);
        }

        // Transfer ERC-20 tokens from sender to treasury
        token.safeTransferFrom(_msgSender(), _treasury, totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Adds an ERC-20 token to the list of accepted payment tokens.
     * @param token The address of the ERC-20 token to add.
     */
    function _addERC20PaymentToken(address token) internal virtual {
        if (token == address(0)) {
            revert InvalidERC20PaymentToken(token);
        }
        if (!_paymentTokens[token]) {
            _paymentTokens[token] = true;
            _paymentTokensList.push(token);
            emit PaymentTokenAdded(token);
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

            emit PaymentTokenRemoved(token);
        }
    }
}
