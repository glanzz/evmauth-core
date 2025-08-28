// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenConfiguration } from "src/common/TokenConfiguration.sol";
import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import { ReentrancyGuardTransientUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";

/**
 * @dev Base mixin for token contracts that adds token pricing and direct purchase functionality.
 * Use this to implement your own purchase logic, or use TokenPurchase or TokenPurchaseERC20 for
 * native currency or ERC-20 token purchases, respectively.
 *
 * With sequential token IDs, a price of 0 means "not for sale" and we can determine if a token
 * exists by checking if its ID is less than _nextTokenId (from TokenConfiguration).
 */
abstract contract TokenPrice is TokenConfiguration, ReentrancyGuardTransientUpgradeable {
    /**
     * @dev Wallet address where token purchase revenues will be sent.
     * This address must be set before any purchases can be made.
     */
    address payable internal _treasury;

    /**
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event TokenPurchased(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasuryUpdated(address caller, address indexed account);

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
     * @dev Error thrown when a purchase is attempted for a token `id` that does not have a price set.
     */
    error TokenNotForSale(uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __TokenPrice_init(address payable initialTreasury) public onlyInitializing {
        __TokenConfiguration_init();
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
     * @dev Returns the address of the current treasury account where funds are collected.
     *
     * @return The address of the treasury account.
     */
    function treasury() public view virtual returns (address) {
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
            revert InvalidTreasuryAddress(account);
        }

        _treasury = account;

        emit TreasuryUpdated(_msgSender(), account);
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
    function _validatePurchase(address receiver, uint256 id, uint256 amount)
        internal
        view
        virtual
        requireTokenExists(id)
        returns (uint256)
    {
        if (receiver == address(0)) {
            revert InvalidReceiverAddress(receiver);
        }
        if (amount == 0) {
            revert InvalidTokenQuantity(amount);
        }

        uint256 price = priceOf(id);
        if (price == 0) {
            revert TokenNotForSale(id);
        }

        return price * amount;
    }

    /**
     * @dev Internal function to mint tokens after successful purchase.
     * Mints the tokens to the receiver and emits the Purchase event.
     *
     * Emits a {TokenPurchased} event where the `caller` may be different than the `receiver`.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     * @param totalPrice The total price for the requested amount of tokens
     */
    function _completePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) internal virtual {
        _mintPurchasedTokens(receiver, id, amount);

        emit TokenPurchased(_msgSender(), receiver, id, amount, totalPrice);
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
}
