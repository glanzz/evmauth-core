// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909X} from "src/ERC6909/ERC6909X.sol";
import {TokenTTL} from "src/common/TokenTTL.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract combines ERC6909X with the TokenTTL extension.
 */
contract ERC6909XT is ERC6909X, TokenTTL {
    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The contract URI.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC6909X(initialDelay, initialDefaultAdmin, uri_)
    {}

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
        override(ERC6909, IERC6909, TokenTTL)
        returns (uint256)
    {
        return TokenTTL.balanceOf(account, id);
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
