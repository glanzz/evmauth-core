// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth1155 } from "src/ERC1155/EVMAuth1155.sol";
import { TokenPurchase } from "src/common/TokenPurchase.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines {EVMAuth1155} with the {TokenPurchase} mixin, allowing tokens to be purchased
 * using the native currency (e.g., ETH, POL).
 */
contract EVMAuth1155P is EVMAuth1155, TokenPurchase {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public virtual initializer {
        __EVMAuth1155P_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __EVMAuth1155P_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __EVMAuth1155_init(initialDelay, initialDefaultAdmin, uri_);
        __TokenPrice_init_unchained(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth1155P_init_unchained() public onlyInitializing {
        // Nothing to initialize
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
     * Emits a {PriceSet} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The identifier of the token type to set the price for.
     * @param price The price to set for the token type.
     */
    function setPrice(uint256 id, uint256 price) public virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setPrice(id, price);
    }

    /**
     * @dev Suspends the price for a specific token ID, making it unavailable for purchase.
     *
     * Emits a {PriceSuspended} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The identifier of the token type to suspend the price for.
     */
    function suspendPrice(uint256 id) public virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _suspendPrice(id);
    }

    /**
     * @dev Internal function to mint purchased tokens after successful purchase.
     *
     * @param to The address to mint tokens to.
     * @param id The token ID to mint.
     * @param amount The amount of tokens to mint.
     */
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        _mint(to, id, amount, "");
    }
}
