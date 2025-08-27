// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth6909 } from "src/ERC6909/EVMAuth6909.sol";
import { TokenPurchaseERC20 } from "src/common/TokenPurchaseERC20.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract combines {EVMAuth6909} with the {TokenPurchaseERC20} mixin, allowing tokens to
 * be purchased using the native currency (e.g., ETH, POL).
 */
contract EVMAuth6909P20 is EVMAuth6909, TokenPurchaseERC20 {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public virtual initializer {
        __EVMAuth6909P20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __EVMAuth6909P20_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __EVMAuth6909_init(initialDelay, initialDefaultAdmin, uri_);
        __TokenPrice_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth6909P20_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Adds a new ERC-20 token address that can be used for purchasing tokens.
     *
     * Emits a {PaymentTokenAdded} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param token The address of the ERC-20 token to be added as a payment option.
     */
    function addERC20PaymentToken(address token) public virtual onlyRole(TREASURER_ROLE) {
        _addERC20PaymentToken(token);
    }

    /**
     * @dev Removes an existing ERC-20 token address from the list of accepted payment tokens.
     *
     * Emits a {PaymentTokenRemoved} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param token The address of the ERC-20 token to be removed from the payment options.
     */
    function removeERC20PaymentToken(address token) public virtual onlyRole(TREASURER_ROLE) {
        super._removeERC20PaymentToken(token);
    }

    /**
     * @dev Sets a new treasury account address where funds will be collected.
     *
     * Emits a {TreasuryUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param account The address of the new treasury account.
     */
    function setTreasury(address payable account) public virtual onlyRole(TREASURER_ROLE) {
        _setTreasury(account);
    }

    /**
     * @dev Sets the price for a specific token ID, making it available for purchase.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param id The identifier of the token type to set the price for.
     * @param price The price to set for the token type.
     */
    function setPrice(uint256 id, uint256 price) public virtual onlyRole(TREASURER_ROLE) {
        _setPrice(id, price);
    }

    /**
     * @dev Internal function to mint purchased tokens after successful purchase.
     *
     * @param to The address to mint tokens to.
     * @param id The token ID to mint.
     * @param amount The amount of tokens to mint.
     */
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        _mint(to, id, amount);
    }
}
