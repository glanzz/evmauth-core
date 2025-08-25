// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC1155X } from "src/ERC1155/ERC1155X.sol";
import { TokenPurchaseERC20 } from "src/common/TokenPurchaseERC20.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines {ERC1155X} with the {TokenPurchaseERC20} mixin, allowing tokens to
 * be purchased using the native currency (e.g., ETH, MATIC).
 */
contract ERC1155XP20 is ERC1155X, TokenPurchaseERC20 {
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
        __ERC1155XP20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __ERC1155XP20_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __ERC1155X_init(initialDelay, initialDefaultAdmin, uri_);
        __TokenPurchaseERC20_init(initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __ERC1155XP20_init_unchained() public onlyInitializing {
        // Nothing to initialize
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
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param id The identifier of the token type to set the price for.
     * @param price The price to set for the token type.
     */
    function setPrice(uint256 id, uint256 price) public virtual onlyRole(TREASURER_ROLE) {
        _setPrice(id, price);
    }

    /**
     * @dev Suspends the price for a specific token ID, making it unavailable for purchase.
     *
     * Emits a {PriceSuspended} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param id The identifier of the token type to suspend the price for.
     */
    function suspendPrice(uint256 id) public virtual onlyRole(TREASURER_ROLE) {
        _suspendPrice(id);
    }
}
