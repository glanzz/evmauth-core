// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Abstract contract that provides a framework for token purchase functionality with multi-currency support.
 * Each token ID can have a native currency price and/or multiple ERC-20 token prices.
 */
abstract contract TokenPurchasable is PausableUpgradeable, ReentrancyGuardTransientUpgradeable {
    // Import SafeERC20 to revert if a transfer returns false
    using SafeERC20 for IERC20;

    /**
     * @dev Struct representing a payment token and its associated price.
     */
    struct PaymentToken {
        address token;
        uint256 price;
    }

    /// @custom:storage-location erc7201:tokenpurchasable.storage.TokenPurchasable
    struct TokenPurchasableStorage {
        /**
         * @dev Wallet address where token purchase revenues will be sent.
         */
        address payable treasury;
        /**
         * @dev Mapping from token `id` to its native currency price.
         * If price is 0, the token cannot be purchased with native currency.
         */
        mapping(uint256 => uint256) nativePrices;
        /**
         * @dev Mapping from token `id` to ERC-20 token address to price.
         * If price is 0, the token cannot be purchased with that ERC-20 token.
         */
        mapping(uint256 => mapping(address => uint256)) erc20Prices;
        /**
         * @dev Mapping from token `id` to list of accepted ERC-20 payment tokens.
         * This is used to enumerate accepted tokens for a given token ID.
         */
        mapping(uint256 => address[]) erc20TokensAccepted;
    }

    /**
     * @dev Storage location for the `TokenPurchasable` contract, as defined by EIP-7201.
     *
     * This is a keccak-256 hash of a unique string, minus 1, and then rounded down to the nearest
     * multiple of 256 bits (32 bytes) to avoid potential storage slot collisions with other
     * upgradeable contracts that may be added to the same deployment.
     *
     * keccak256(abi.encode(uint256(keccak256("tokenpurchasable.storage.TokenPurchasable")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 private constant TokenPurchasableStorageLocation =
        0x54c84cf2875b53587e3bd1a41cdb4ae126fe9184d0b1bd9183d4f9005d2ff600;

    /**
     * @dev Returns the storage struct for the `TokenPurchasable` contract.
     */
    function _getTokenPurchasableStorage() private pure returns (TokenPurchasableStorage storage $) {
        assembly {
            $.slot := TokenPurchasableStorageLocation
        }
    }

    /**
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event TokenPurchased(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasuryUpdated(address caller, address indexed account);

    /**
     * @dev Emitted when a native currency price is set for a token.
     */
    event NativePriceSet(uint256 indexed id, uint256 price);

    /**
     * @dev Emitted when an ERC-20 price is set for a token.
     */
    event ERC20PriceSet(uint256 indexed id, address indexed token, uint256 price);

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
     * @dev Error thrown when the ERC-20 token being used for payment is not accepted for the specific token ID.
     */
    error InvalidERC20PaymentToken(address token);

    /**
     * @dev Error thrown when a purchase is attempted with an invalid amount.
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
     * @dev Error thrown when a native currency purchase is attempted for a token that doesn't have a native price.
     */
    error TokenNotForSaleWithNativeCurrency(uint256 id);

    /**
     * @dev Error thrown when an ERC-20 purchase is attempted for a token that doesn't accept that payment token.
     */
    error TokenNotForSaleWithERC20(uint256 id, address token);

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
     * @dev Returns the native currency price of a given token `id`.
     *
     * @param id The identifier of the token type to get the price for.
     * @return price The native currency price of the given token `id` (0 if not for sale with native currency).
     */
    function tokenPrice(uint256 id) public view virtual returns (uint256 price) {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        price = $.nativePrices[id];

        if (price == 0) {
            revert TokenNotForSaleWithNativeCurrency(id);
        }

        return price;
    }

    /**
     * @dev Returns the price of a given token `id` for a given ERC-20 token.
     *
     * @param id The identifier of the token type to get the price for.
     * @param paymentToken The address of the ERC-20 token.
     * @return price The price in the specified ERC-20 token (0 if not accepted).
     */
    function tokenERC20Price(uint256 id, address paymentToken) public view virtual returns (uint256 price) {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        price = $.erc20Prices[id][paymentToken];

        if (price == 0) {
            revert TokenNotForSaleWithERC20(id, paymentToken);
        }

        return price;
    }

    /**
     * @dev Returns the list of prices for a given token `id` in all accepted ERC-20 payment tokens.
     *
     * @param id The identifier of the token type to get the prices for.
     * @return prices An array of {PaymentToken} structs, each containing an ERC-20 token address and price.
     */
    function tokenERC20Prices(uint256 id) public view virtual returns (PaymentToken[] memory prices) {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        address[] storage acceptedTokens = $.erc20TokensAccepted[id];
        prices = new PaymentToken[](acceptedTokens.length);

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            address token = acceptedTokens[i];
            uint256 price = $.erc20Prices[id][token];
            prices[i] = PaymentToken(token, price);
        }
    }

    /**
     * @dev Checks if a given ERC-20 token is accepted for payment for a specific token `id`.
     *
     * @param id The identifier of the token type to check.
     * @param paymentToken The address of the ERC-20 token to check.
     * @return True if the ERC-20 token is accepted for payment, false otherwise.
     */
    function isAcceptedERC20PaymentToken(uint256 id, address paymentToken) public view virtual returns (bool) {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        return $.erc20Prices[id][paymentToken] > 0;
    }

    /**
     * @dev Returns the address of the current treasury account where funds are collected.
     *
     * @return The address of the treasury account.
     */
    function treasury() public view virtual returns (address) {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        return $.treasury;
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * using native currency. The caller must send sufficient payment with the transaction.
     *
     * Emits a {TokenPurchased} event where the `caller` and `receiver` are the same.
     *
     * Requirements:
     * - The contract must not be paused.
     * - The amount must be greater than zero.
     * - The token `id` must have a native currency price set.
     * - The payment sent with the transaction must be sufficient.
     *
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function purchase(uint256 id, uint256 amount) external payable virtual whenNotPaused nonReentrant {
        _purchaseFor(_msgSender(), id, amount);
    }

    /**
     * @dev Allows the caller to purchase a specific `amount` of tokens of type `id`
     * for a designated `receiver` using native currency.
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
     * @dev Allows the caller to purchase tokens using an ERC-20 token.
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
     * @dev Allows the caller to purchase tokens for a designated `receiver` using an ERC-20 token.
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
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseFor(address receiver, uint256 id, uint256 amount) internal virtual {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();

        _validateReceiver(receiver);
        _validateAmount(amount);

        uint256 price = $.nativePrices[id];
        if (price == 0) revert TokenNotForSaleWithNativeCurrency(id);

        uint256 totalPrice = price * amount;

        if (msg.value < totalPrice) revert InsufficientPayment(id, amount, totalPrice, msg.value);

        // Refund excess payment to the sender
        if (msg.value > totalPrice) payable(_msgSender()).transfer(msg.value - totalPrice);

        // Transfer payment to treasury
        payable($.treasury).transfer(totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
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
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();

        _validateReceiver(receiver);
        _validateAmount(amount);

        uint256 price = $.erc20Prices[id][paymentToken];
        if (price == 0) revert TokenNotForSaleWithERC20(id, paymentToken);

        uint256 totalPrice = price * amount;

        IERC20 token = IERC20(paymentToken);

        // Check allowance
        uint256 allowance = token.allowance(_msgSender(), address(this));
        if (allowance < totalPrice) revert InsufficientERC20Allowance(paymentToken, totalPrice, allowance);

        // Check balance
        uint256 balance = token.balanceOf(_msgSender());
        if (balance < totalPrice) revert InsufficientERC20Balance(paymentToken, totalPrice, balance);

        // Transfer ERC-20 tokens from sender to treasury
        token.safeTransferFrom(_msgSender(), $.treasury, totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Sets the native currency price for a given token `id`.
     * Set to 0 to disable native currency purchases.
     *
     * @param id The identifier of the token type.
     * @param price The native currency price to set.
     */
    function _setPrice(uint256 id, uint256 price) internal virtual {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        $.nativePrices[id] = price;
        emit NativePriceSet(id, price);
    }

    /**
     * @dev Sets the price for a given token `id` in a specific ERC-20 token.
     * Set price to 0 to disable purchases with that ERC-20 token.
     * Automatically adds the token to the global accepted list if price > 0.
     *
     * @param id The identifier of the token type.
     * @param token The address of the ERC-20 token.
     * @param price The price in the specified ERC-20 token to set.
     */
    function _setERC20Price(uint256 id, address token, uint256 price) internal virtual {
        if (token == address(0)) {
            revert InvalidERC20PaymentToken(token);
        }

        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();
        $.erc20Prices[id][token] = price;

        // If price > 0 and token not already in accepted list, add it
        if (price > 0) {
            address[] storage acceptedTokens = $.erc20TokensAccepted[id];
            bool alreadyAccepted = false;
            for (uint256 i = 0; i < acceptedTokens.length; i++) {
                if (acceptedTokens[i] == token) {
                    alreadyAccepted = true;
                    break;
                }
            }
            if (!alreadyAccepted) {
                acceptedTokens.push(token);
            }
        } else {
            // If price is set to 0, remove the token from the accepted list
            address[] storage acceptedTokens = $.erc20TokensAccepted[id];
            for (uint256 i = 0; i < acceptedTokens.length; i++) {
                if (acceptedTokens[i] == token) {
                    acceptedTokens[i] = acceptedTokens[acceptedTokens.length - 1];
                    acceptedTokens.pop();
                    break;
                }
            }
        }

        emit ERC20PriceSet(id, token, price);
    }

    /**
     * @dev Sets multiple ERC-20 prices for a token ID at once.
     *
     * @param id The identifier of the token type.
     * @param configs An array of payment token configurations.
     */
    function _setERC20Prices(uint256 id, PaymentToken[] calldata configs) internal virtual {
        for (uint256 i = 0; i < configs.length; i++) {
            _setERC20Price(id, configs[i].token, configs[i].price);
        }
    }

    /**
     * @dev Sets the treasury address where purchase revenues will be sent.
     *
     * @param account The address where purchase revenues will be sent.
     */
    function _setTreasury(address payable account) internal virtual {
        TokenPurchasableStorage storage $ = _getTokenPurchasableStorage();

        if (account == address(0)) revert InvalidTreasuryAddress(account);

        $.treasury = account;
        emit TreasuryUpdated(_msgSender(), account);
    }

    /**
     * @dev Validates the receiver address.
     *
     * @param receiver The address to validate.
     */
    function _validateReceiver(address receiver) internal pure virtual {
        if (receiver == address(0)) revert InvalidReceiverAddress(receiver);
    }

    /**
     * @dev Validates the purchase amount.
     *
     * @param amount The amount to validate.
     */
    function _validateAmount(uint256 amount) internal pure virtual {
        if (amount == 0) revert InvalidTokenQuantity(amount);
    }

    /**
     * @dev Internal function to mint tokens after successful purchase.
     *
     * Emits a {TokenPurchased} event.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @param totalPrice The total price paid for the tokens.
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
