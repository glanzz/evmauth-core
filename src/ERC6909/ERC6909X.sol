// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TokenAccessControl} from "src/common/TokenAccessControl.sol";
import {TokenNonTransferable} from "src/common/TokenNonTransferable.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {ERC6909ContentURI} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909ContentURI.sol";
import {ERC6909Metadata} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909Metadata.sol";
import {ERC6909TokenSupply} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909TokenSupply.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract consolidates ERC6909 with the ContentURI, Metadata, and TokenSupply extensions.
 * It also integrates role-based access control and non-transferable token features.
 */
contract ERC6909X is
    ERC6909ContentURI,
    ERC6909Metadata,
    ERC6909TokenSupply,
    TokenNonTransferable,
    TokenAccessControl
{
    /**
     * @dev Error thrown when a transfer is attempted with the same sender and recipient addresses.
     */
    error ERC6909InvalidSelfTransfer(address sender);

    /**
     * @dev Error thrown when a transfer is attempted with a zero value `amount`.
     */
    error ERC6909InvalidZeroValueTransfer();

    /**
     * @dev Initializes the contract with an initial delay, default admin address, and contract URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The contract URI.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        TokenAccessControl(initialDelay, initialDefaultAdmin)
    {
        _setContractURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC6909, IERC165, TokenAccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Mints `amount` tokens of token type `id` to account `to`.
     *
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     *
     * @param to The address to mint tokens to.
     * @param id The token ID to mint.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount);
    }

    /**
     * @dev Burns `amount` tokens of token type `id` from account `from`.
     *
     * Requirements:
     * - The caller must have the `BURNER_ROLE`.
     *
     * @param from The address to burn tokens from.
     * @param id The token ID to burn.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, id, amount);
    }

    /**
     * @dev Sets the contract URI.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param contractURI The contract URI to set.
     */
    function setContractURI(string memory contractURI) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setContractURI(contractURI);
    }

    /**
     * @dev Sets the content URI for a specific token ID.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to set the content URI for.
     * @param contentURI The content URI to set.
     */
    function setTokenURI(uint256 id, string memory contentURI) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenURI(id, contentURI);
    }

    /**
     * @dev Sets the metadata for a specific token ID.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to set metadata for.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param decimals The decimals of the token.
     */
    function setTokenMetadata(uint256 id, string memory name, string memory symbol, uint8 decimals)
        external
        onlyRole(TOKEN_MANAGER_ROLE)
    {
        _setName(id, name);
        _setSymbol(id, symbol);
        _setDecimals(id, decimals);
    }

    /**
     * @dev Sets whether a token ID is non-transferable.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to configure.
     * @param nonTransferable Whether the token should be non-transferable.
     */
    function setNonTransferable(uint256 id, bool nonTransferable) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setNonTransferable(id, nonTransferable);
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - the `from` and `to` addresses must not be the same.
     * - if both `from` and `to` are non-zero, token `id` must be transferable.
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `amount`.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param id The identifier of the token type to transfer.
     * @param amount The number of tokens to transfer.
     */
    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909, ERC6909TokenSupply)
        whenNotPaused
        denyTransferIfNonTransferable(from, to, id)
    {
        // Check if the sender and receiver are the same
        if (from == to) {
            revert ERC6909InvalidSelfTransfer(from);
        }

        // Check if the amount is zero
        if (amount == 0) {
            revert ERC6909InvalidZeroValueTransfer();
        }

        super._update(from, to, id, amount);
    }
}
