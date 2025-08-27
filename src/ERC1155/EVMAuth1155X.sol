// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth1155 } from "src/ERC1155/EVMAuth1155.sol";
import { TokenExpiry } from "src/common/TokenExpiry.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Arrays } from "@openzeppelin/contracts/utils/Arrays.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines {EVMAuth1155} with the {TokenExpiry} mixin, which adds automatic token expiry
 * for any token type that has a time-to-live (TTL) set.
 */
contract EVMAuth1155X is EVMAuth1155, TokenExpiry {
    using Arrays for uint256[];
    using Arrays for address[];

    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     */
    function initialize(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        virtual
        override
        initializer
    {
        __EVMAuth1155X_init(initialDelay, initialDefaultAdmin, uri_);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     */
    function __EVMAuth1155X_init(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        onlyInitializing
    {
        __EVMAuth1155_init(initialDelay, initialDefaultAdmin, uri_);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth1155X_init_unchained() public onlyInitializing {
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
        override(ERC1155Upgradeable, TokenExpiry)
        returns (uint256)
    {
        return TokenExpiry.balanceOf(account, id);
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
            batchBalances[i] = TokenExpiry.balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
        }

        return batchBalances;
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
