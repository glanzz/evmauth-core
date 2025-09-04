// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Abstract contract that provides a framework for token purchase functionality. The actual purchase
 * logic (e.g., payment processing, token minting) must be implemented by the inheriting contract.
 */
abstract contract TokenPurchasable is PausableUpgradeable, ReentrancyGuardTransientUpgradeable {
    // Import SafeERC20 to revert if a transfer returns false
    using SafeERC20 for IERC20;

    /**
     * @dev Wallet address where token purchase revenues will be sent.
     * This address must be set before any purchases can be made.
     */
    address payable internal _treasury;

    /**
     * @dev Mapping from token `id` to its `price` (in whichever currency is used for purchases).
     */
    mapping(uint256 id => uint256 price) private _prices;

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
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event TokenPurchased(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Error thrown when the payer has insufficient allowance for the ERC-20 token payment.
     */
    error InsufficientERC20Allowance(address token, uint256 required, uint256 allowance);

    /**
     * @dev Error thrown when the payer has insufficient balance of the ERC-20 token for the payment.
     */
    error InsufficientERC20Balance(address token, uint256 required, uint256 balance);

    /**
     * @dev Error thrown when the payment made for a purchase is insufficient.
     */
    error InsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);

    /**
     * @dev Error thrown when the ERC-20 token being used for payment is not accepted.
     */
    error InvalidERC20PaymentToken(address token);

    /**
     * @dev Error thrown when a purchase is attempted an invalid amount.
     */
    error InvalidTokenQuantity(uint256 amount);

    /**
     * @dev Error thrown when a purchase is attempted with an invalid receiver address.
     */
    error InvalidReceiverAddress(address receiver);

    /**
     * @dev Error thrown when the treasury address being set is invalid.
     */
    error InvalidTreasuryAddress(address treasury);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasuryUpdated(address caller, address indexed account);

    /**
     * @dev Error thrown when a purchase is attempted for a token `id` that does not have a price set.
     */
    error TokenNotForSale(uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPurchasable_init(address payable initialTreasury) internal onlyInitializing {
        __TokenPurchasable_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPurchasable_init_unchained(address payable initialTreasury) internal onlyInitializing {
        _setTreasury(initialTreasury);
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
     * @dev Returns the price of a given token `id`.
     *
     * Must be implemented by the inheriting contract, or combined with {TokenConfiguration}.
     *
     * @param id The identifier of the token type to get the price for.
     * @return uint256 The price of the given token `id`.
     */
    function tokenPrice(uint256 id) public view virtual returns (uint256) {
        return _prices[id];
    }

    /**
     * @dev Returns the address of the current treasury account where funds are collected.
     *
     * @return The address of the treasury account.
     */
    function treasury() public view virtual returns (address) {
        return _treasury;
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * using native currency. The caller must send sufficient payment with the transaction.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {TokenPurchased} event where the `caller` and `receiver` are the same.
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
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
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
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * using the specified ERC-20 `paymentToken`. The caller must have approved
     * this contract to spend sufficient amount of the ERC-20 token.
     *
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
    function purchaseWithERC20(address paymentToken, uint256 id, uint256 amount)
        external
        virtual
        whenNotPaused
        nonReentrant
    {
        _purchaseWithERC20For(_msgSender(), paymentToken, id, amount);
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * for a designated `receiver` using the specified ERC-20 `paymentToken`.
     * The caller must have approved this contract to spend sufficient amount
     * of the ERC-20 token.
     *
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
    function purchaseWithERC20For(address receiver, address paymentToken, uint256 id, uint256 amount)
        external
        virtual
        whenNotPaused
        nonReentrant
    {
        _purchaseWithERC20For(receiver, paymentToken, id, amount);
    }

    /**
     * @dev Internal function to handle the purchase logic with native currency.
     * It validates the purchase, checks payment sufficiency, transfers funds to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
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
            revert InsufficientPayment(id, amount, totalPrice, msg.value);
        }

        // Refund excess payment to the sender
        if (msg.value > totalPrice) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        }

        // Transfer payment to treasury
        payable(_treasury).transfer(totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
     * It validates the purchase, transfers ERC-20 tokens from sender to treasury,
     * and mints the tokens to the receiver.
     *
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
    function _purchaseWithERC20For(address receiver, address paymentToken, uint256 id, uint256 amount)
        internal
        virtual
    {
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
     *
     * Emits a {PaymentTokenAdded} event if the token was not already accepted.
     *
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
     *
     * Emits a {PaymentTokenRemoved} event if the token was previously accepted.
     *
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

    /**
     * @dev Sets the `price` for a given token `id`.
     *
     * @param id The identifier of the token type to purchase.
     * @param price The price to set for the token type.
     */
    function _setPrice(uint256 id, uint256 price) internal virtual {
        _prices[id] = price;
    }

    /**
     * @dev Sets the treasury address where purchase revenues will be sent.
     *
     * Emits a {TreasuryUpdated} event.
     *
     * Reverts if `account` is the zero address.
     *
     * @param account The address where purchase revenues will be sent.
     */
    function _setTreasury(address payable account) internal virtual {
        if (account == address(0)) {
            revert InvalidTreasuryAddress(account);
        }

        _treasury = account;

        emit TreasuryUpdated(_msgSender(), account);
    }

    /**
     * @dev Internal validation for purchase operations.
     * Validates receiver address, amount, and price configuration.
     *
     * Reverts with {InvalidReceiverAddress} if `receiver` is the zero address.
     * Reverts with {InvalidTokenQuantity} if `amount` is zero.
     * Reverts with {TokenNotForSale} if the token price for token `id` is zero.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return totalPrice The total price for the requested amount of tokens.
     */
    function _validatePurchase(address receiver, uint256 id, uint256 amount) internal view virtual returns (uint256) {
        if (receiver == address(0)) {
            revert InvalidReceiverAddress(receiver);
        }
        if (amount == 0) {
            revert InvalidTokenQuantity(amount);
        }

        uint256 _price = tokenPrice(id);
        if (_price == 0) {
            revert TokenNotForSale(id);
        }

        return _price * amount;
    }

    /**
     * @dev Internal function to mint tokens after successful purchase.
     *
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @param totalPrice The total price for the requested amount of tokens.
     */
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal virtual {
        _mintPurchasedTokens(receiver, id, amount);

        emit TokenPurchased(_msgSender(), receiver, id, amount, totalPrice);
    }

    /**
     * @dev Internal function to mint the purchased tokens.
     *
     * This function must be implemented by the inheriting contract.
     *
     * @param to The address to mint tokens to.
     * @param id The token ID to mint.
     * @param amount The amount of tokens to mint.
     */
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual;
}
