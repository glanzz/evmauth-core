// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909Price} from "./IERC6909Price.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract that supports the direct purchase of tokens.
 * This contract contains common functionality for both native currency and ERC-20 token purchases.
 * Concrete implementations must define the purchase and purchaseFor methods.
 */
abstract contract ERC6909Price is ReentrancyGuard, ERC6909, IERC6909Price {
    // Data structure that holds the price for a token and whether it has been set
    struct PriceConfig {
        bool isSet; // Price can be 0, so we need a flag to indicate if it was intentionally set to 0
        uint256 price; // Price for the token ID
    }

    // Token ID => price mapping
    mapping(uint256 => PriceConfig) private _priceConfigs;

    // Wallet address where token purchase revenues will be sent
    address payable private _treasury;

    // Errors
    error ERC6909PriceInvalidAmount(uint256 amount);
    error ERC6909PriceInvalidReceiver(address receiver);
    error ERC6909PriceInvalidTreasury(address treasury);
    error ERC6909PriceTokenPriceNotSet(uint256 id);

    /**
     * @dev Sets the initial `_treasury` address that will receive token purchase revenues.
     *
     * Emits a {TreasuryUpdated} event.
     *
     * Revert if `treasuryAccount` is the zero address.
     */
    constructor(address payable treasuryAccount) {
        _setTreasury(treasuryAccount);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, IERC165) returns (bool) {
        return interfaceId == type(IERC6909Price).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909Price
    function priceIsSet(uint256 id) external view returns (bool) {
        return _priceConfigs[id].isSet;
    }

    /// @inheritdoc IERC6909Price
    function priceOf(uint256 id) external view returns (uint256) {
        if (!_priceConfigs[id].isSet) {
            // We need to revert here, to prevent un-configured tokens from being treated as zero-cost
            revert ERC6909PriceTokenPriceNotSet(id);
        }

        return _priceConfigs[id].price;
    }

    /// @inheritdoc IERC6909Price
    function treasury() external view virtual returns (address) {
        return _treasury;
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
    function _validatePurchase(address receiver, uint256 id, uint256 amount) internal view returns (uint256) {
        if (receiver == address(0)) {
            revert ERC6909PriceInvalidReceiver(receiver);
        }
        if (amount == 0) {
            revert ERC6909PriceInvalidAmount(amount);
        }
        if (!_priceConfigs[id].isSet) {
            revert ERC6909PriceTokenPriceNotSet(id);
        }

        return _priceConfigs[id].price * amount;
    }

    /**
     * @dev Internal function to mint tokens after successful purchase.
     * Mints the tokens to the receiver and emits the Purchase event.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @param totalPrice The total price for the requested amount of tokens
     */
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal {
        // Mint the tokens to the receiver
        super._mint(receiver, id, amount);

        emit Purchase(_msgSender(), receiver, id, amount, totalPrice);
    }

    /**
     * @dev Disables token purchases for a specific token `id` by resetting its PriceConfig.
     * After calling this function, priceIsSet will return false for the token `id` and
     * _validatePurchase will revert if called with this `id`, suspending purchases.
     * Call _setTokenPrice to re-enable purchases for the token `id`.
     *
     * Emits a {ERC6909PriceSuspended} event.
     *
     * @param id The identifier of the token type for which to disable the sale.
     */
    function _suspendTokenPrice(uint256 id) internal {
        // Disable the sale by resetting PriceConfig
        _priceConfigs[id] = PriceConfig({isSet: false, price: 0});
        emit ERC6909PriceSuspended(_msgSender(), id);
    }

    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Emits a {ERC6909PriceUpdated} event.
     *
     * @param id The identifier of the token type for which to set the price.
     * @param price The price to set for the token type.
     */
    function _setTokenPrice(uint256 id, uint256 price) internal {
        _priceConfigs[id] = PriceConfig({isSet: true, price: price});

        emit ERC6909PriceUpdated(_msgSender(), id, price);
    }

    /**
     * @dev Returns the treasury address for internal use.
     *
     * @return The address of the treasury where purchase revenues will be sent.
     */
    function _getTreasury() internal view returns (address payable) {
        return _treasury;
    }

    /**
     * @dev Sets the treasury address where purchase revenues will be sent.
     *
     * If you want to keep the treasury address private or implement custom logic,
     * you can override this function and the `treasury` function.
     *
     * Emits a {TreasuryUpdated} event.
     *
     * Reverts if `treasuryAccount` is the zero address.
     *
     * @param treasuryAccount The address where purchase revenues will be sent.
     */
    function _setTreasury(address payable treasuryAccount) internal virtual {
        if (treasuryAccount == address(0)) {
            revert ERC6909PriceInvalidTreasury(treasuryAccount);
        }

        _treasury = treasuryAccount;

        emit TreasuryUpdated(_msgSender(), treasuryAccount);
    }
}
