// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth6909P20 } from "src/ERC6909/EVMAuth6909P20.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { TokenExpiry } from "src/common/TokenExpiry.sol";
import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import { ERC6909Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC6909/draft-ERC6909Upgradeable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract combines {EVMAuth6909P20} with the {TokenExpiry} mixin, which adds automatic token expiry
 * for any token type that has a time-to-live (TTL) set.
 */
contract EVMAuth6909XP20 is EVMAuth6909P20, TokenExpiry {
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
        __EVMAuth6909XP20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __EVMAuth6909XP20_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __EVMAuth6909P20_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth6909XP20_init_unchained() public onlyInitializing {
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
        override(ERC6909Upgradeable, IERC6909, TokenExpiry)
        returns (uint256)
    {
        return TokenExpiry.balanceOf(account, id);
    }

    /**
     * @dev Sets the ttl for a specific token ID, making it available for purchase.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The identifier of the token type to set the ttl for.
     * @param ttl The ttl to set for the token type.
     */
    function setTTL(uint256 id, uint256 ttl) public virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTTL(id, ttl);
    }
}
