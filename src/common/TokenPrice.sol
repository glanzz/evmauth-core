// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

/**
 * @dev Base mixin for token contracts that adds token pricing and direct purchase functionality.
 * Use this to implement your own purchase logic, or use TokenPurchase or TokenPurchaseERC20 for
 * native currency or ERC-20 token purchases, respectively.
 */
abstract contract TokenPrice is ContextUpgradeable, ReentrancyGuardTransientUpgradeable {
    /**
     * @dev Data structure that holds the price for a token and whether it has been set.
     * This structure allows us to differentiate between a token that has a price intentionally set to 0
     * and one that has not had its price set at all.
     */
    struct PriceConfig {
        bool isSet; // Price can be 0, so we need a flag to indicate if it was intentionally set to 0
        uint256 price; // Price for the token ID
    }

    /**
     * @dev Mapping from token ID to its price configuration.
     */
    mapping(uint256 => PriceConfig) private _priceConfigs;

    /**
     * @dev Wallet address where token purchase revenues will be sent.
     * This address must be set before any purchases can be made.
     */
    address payable private _treasury;

    /**
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Emitted when the price of a token `id` is set by `caller`.
     */
    event PriceUpdated(address caller, uint256 indexed id, uint256 price);

    /**
     * @dev Emitted when purchase of a token `id` is disabled by `caller`.
     */
    event PriceSuspended(address caller, uint256 indexed id);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasuryUpdated(address caller, address indexed account);

    /**
     * @dev Error thrown when a purchase is attempted an invalid amount.
     */
    error TokenPriceInvalidAmount(uint256 amount);

    /**
     * @dev Error thrown when a purchase is attempted with an invalid receiver address.
     */
    error TokenPriceInvalidReceiver(address receiver);

    /**
     * @dev Error thrown when the treasury address being set is invalid.
     */
    error TokenPriceInvalidTreasury(address treasury);

    /**
     * @dev Error thrown when a purchase is attempted for a token `id` that does not have a price set.
     */
    error TokenPriceNotSet(uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPrice_init(address payable initialTreasury) public onlyInitializing {
        __TokenPrice_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPrice_init_unchained(address payable initialTreasury) public onlyInitializing {
        _setTreasury(initialTreasury);
    }

    /**
     * @dev Returns true if the price for a specific token `id` has been set.
     * This is useful to check if a token can be purchased.
     *
     * If the price is set to 0, it will still return true, as it indicates that the price was intentionally set to 0.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the price is set for the token `id`.
     */
    function isPriceSet(uint256 id) external view returns (bool) {
        return _priceConfigs[id].isSet;
    }

    /**
     * @dev Returns the price of a specific token `id`.
     *
     * Revert if the price is not set for the token `id`.
     *
     * @param id The identifier of the token type to get the price for.
     * @return uint256 representing the price of the token `id`.
     */
    function priceOf(uint256 id) external view returns (uint256) {
        if (!_priceConfigs[id].isSet) {
            // We need to revert here, to prevent un-configured tokens from being treated as zero-cost
            revert TokenPriceNotSet(id);
        }

        return _priceConfigs[id].price;
    }

    /**
     * @dev Returns the address of the current treasury account where funds are collected.
     *
     * @return The address of the treasury account.
     */
    function treasury() public view virtual returns (address) {
        return _getTreasury();
    }

    /**
     * @dev Internal validation for purchase operations.
     * Validates receiver address, amount, and price configuration.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @return totalPrice The total price for the requested amount of tokens
     */
    function _validatePurchase(address receiver, uint256 id, uint256 amount) internal view virtual returns (uint256) {
        if (receiver == address(0)) {
            revert TokenPriceInvalidReceiver(receiver);
        }
        if (amount == 0) {
            revert TokenPriceInvalidAmount(amount);
        }
        if (!_priceConfigs[id].isSet) {
            revert TokenPriceNotSet(id);
        }

        return _priceConfigs[id].price * amount;
    }

    /**
     * @dev Internal function to mint tokens after successful purchase.
     * Mints the tokens to the receiver and emits the Purchase event.
     *
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @param totalPrice The total price for the requested amount of tokens
     */
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal virtual {
        _mintPurchasedTokens(receiver, id, amount);
        emit Purchase(_msgSender(), receiver, id, amount, totalPrice);
    }

    /**
     * @dev Internal function to mint the purchased tokens.
     * This function must be implemented by the inheriting contract to define how tokens are minted.
     *
     * @param to The address to mint tokens to.
     * @param id The token ID to mint.
     * @param amount The amount of tokens to mint.
     */
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual;

    /**
     * @dev Returns the treasury address for internal use.
     *
     * @return The address of the treasury where purchase revenues will be sent.
     */
    function _getTreasury() internal view virtual returns (address payable) {
        return _treasury;
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
            revert TokenPriceInvalidTreasury(account);
        }

        _treasury = account;

        emit TreasuryUpdated(_msgSender(), account);
    }

    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Emits a {EVMAuth1155PriceUpdated} event.
     *
     * @param id The identifier of the token type for which to set the price.
     * @param price The price to set for the token type.
     */
    function _setPrice(uint256 id, uint256 price) internal {
        _priceConfigs[id] = PriceConfig({ isSet: true, price: price });

        emit PriceUpdated(_msgSender(), id, price);
    }

    /**
     * @dev Disables token purchases for a specific token `id` by resetting its PriceConfig.
     * After calling this function, isPriceSet will return false for the token `id` and
     * _validatePurchase will revert if called with this `id`, suspending purchases.
     * Call _setPrice to re-enable purchases for the token `id`.
     *
     * This function does nothing if the price is not set.
     *
     * Emits a {EVMAuth1155PriceSuspended} event.
     *
     * @param id The identifier of the token type for which to disable the sale.
     */
    function _suspendPrice(uint256 id) internal {
        if (_priceConfigs[id].isSet) {
            _priceConfigs[id] = PriceConfig({ isSet: false, price: 0 });
            emit PriceSuspended(_msgSender(), id);
        }
    }
}
