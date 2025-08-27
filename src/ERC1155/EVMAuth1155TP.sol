// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth1155P } from "src/ERC1155/EVMAuth1155P.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { TokenTTL } from "src/common/TokenTTL.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Arrays } from "@openzeppelin/contracts/utils/Arrays.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines {EVMAuth1155P} with the {TokenTTL} mixin, which adds automatic token expiry
 * for any token type that has a time-to-live (TTL) set.
 */
contract EVMAuth1155TP is EVMAuth1155P, TokenTTL {
    using Arrays for uint256[];
    using Arrays for address[];

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
    ) public virtual override initializer {
        __EVMAuth1155TP_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __EVMAuth1155TP_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public onlyInitializing {
        __EVMAuth1155P_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth1155TP_init_unchained() public onlyInitializing {
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
        override(ERC1155Upgradeable, TokenTTL)
        returns (uint256)
    {
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

    /**
     * @dev Override to configure both price and TTL when a token is configured.
     */
    function _afterTokenConfiguration(uint256 tokenId, TokenConfig memory config) internal virtual override {
        super._afterTokenConfiguration(tokenId, config); // This calls EVMAuth1155P's version which handles price
        _configureTokenTTL(tokenId, config.ttl);
    }

    /**
     * @dev Override to include both price and TTL in token configuration.
     */
    function _getTokenConfig(uint256 id) internal view virtual override returns (TokenConfig memory config) {
        config = super._getTokenConfig(id); // This gets price from EVMAuth1155P
        config.ttl = _getTokenTTL(id);
    }
}
