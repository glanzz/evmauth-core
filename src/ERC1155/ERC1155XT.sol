// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155X} from "src/ERC1155/ERC1155X.sol";
import {TokenTTL} from "src/common/TokenTTL.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines ERC1155X with the TokenTTL extension.
 */
contract ERC1155XT is ERC1155X, TokenTTL {
    using Arrays for uint256[];
    using Arrays for address[];

    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The base URI for token metadata.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC1155X(initialDelay, initialDefaultAdmin, uri_)
    {}

    /**
     * @dev Returns the balance of specific token `id` for the given `account`, excluding expired tokens.
     *
     * @param account The address of the account to check the balance for.
     * @param id The identifier of the token type to check the balance for.
     * @return The balance of the token `id` for the specified `account`, excluding expired tokens.
     */
    function balanceOf(address account, uint256 id) public view virtual override(ERC1155, TokenTTL) returns (uint256) {
        return TokenTTL.balanceOf(account, id);
    }

    /**
     * @dev Returns the balance of specific token `ids` for the given `accounts`, excluding expired tokens.
     *
     * @param accounts[] The addresses of the accounts to check the balances for.
     * @param ids[] The identifiers of the token types to check the balances for.
     * @return The balances of the token `ids` for the specified `accounts`, excluding expired tokens.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        if (accounts.length != ids.length) {
            revert IERC1155Errors.ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = TokenTTL.balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
        }

        return batchBalances;
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
