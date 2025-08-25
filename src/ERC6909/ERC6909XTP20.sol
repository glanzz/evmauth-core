// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC6909XP20 } from "src/ERC6909/ERC6909XP20.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { TokenTTL } from "src/common/TokenTTL.sol";
import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import { ERC6909Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC6909/draft-ERC6909Upgradeable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract combines {ERC6909XP20} with the {TokenTTL} mixin, which adds automatic token expiry
 * for any token type that has a time-to-live (TTL) set.
 */
contract ERC6909XTP20 is ERC6909XP20, TokenTTL {
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
    ) public virtual override initializer {
        __ERC6909XTP20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __ERC6909XTP20_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __ERC6909XP20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __ERC6909XTP20_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Returns the balance of specific token `id` for the given `account`, excluding expired tokens.
     *
     * @param account The address of the account to check the balance for.
     * @param id The identifier of the token type to check the balance for.
     * @return The balance of the token `id` for the specified `account`, excluding expired tokens.
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909Upgradeable, IERC6909, TokenTTL)
        returns (uint256)
    {
        return TokenTTL.balanceOf(account, id);
    }

    /**
     * @dev Returns the address of the current treasury account where funds are collected.
     *
     * @return The address of the treasury account.
     */
    function treasury() public view virtual override returns (address) {
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
    function setTreasury(address payable account) public virtual override onlyRole(TREASURER_ROLE) {
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
    function setPrice(uint256 id, uint256 price) public virtual override onlyRole(TREASURER_ROLE) {
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
    function suspendPrice(uint256 id) public virtual override onlyRole(TREASURER_ROLE) {
        _suspendPrice(id);
    }

    /**
     * @dev Prunes balance records for a specific account, removing entries that are expired or
     * have a zero balances. This is handled automatically during transfers and minting, but can
     * be manually invoked to clean up storage.
     */
    function pruneBalanceRecords(address account, uint256 id) public virtual {
        _pruneBalanceRecords(account, id);
    }

    /**
     * @dev Sets the ttl for a specific token ID, making it available for purchase.
     *
     * Emits a {ttlSet} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     *
     * @param id The identifier of the token type to set the ttl for.
     * @param ttl The ttl to set for the token type.
     */
    function setTTL(uint256 id, uint256 ttl) public virtual onlyRole(TREASURER_ROLE) {
        _setTTL(id, ttl);
    }
}
