// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909Base} from "./IERC6909Base.sol";
import {
    IERC6909,
    IERC6909ContentURI,
    IERC6909Metadata,
    IERC6909TokenSupply
} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {ERC6909ContentURI} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909ContentURI.sol";
import {ERC6909Metadata} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909Metadata.sol";
import {ERC6909TokenSupply} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909TokenSupply.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract consolidates ERC6909 with the ContentURI, Metadata, and TokenSupply extensions.
 * It serves as a base contract for more complex implementations.
 */
abstract contract ERC6909Base is IERC6909Base, ERC6909ContentURI, ERC6909Metadata, ERC6909TokenSupply, Pausable {
    // Token ID => is non-transferable mapping (tokens are transferable by default)
    mapping(uint256 => bool) private _nonTransferableTokens;

    // Errors
    error ERC6909NonTransferableToken(uint256 id);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, IERC165) returns (bool) {
        return interfaceId == type(IERC6909Base).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909Base
    function isTransferable(uint256 id) public view virtual returns (bool) {
        return !_nonTransferableTokens[id];
    }

    /**
     * @dev Sets the non-transferable status of a specific token `id`.
     *
     * Emits a {ERC6909NonTransferableUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function _setNonTransferable(uint256 id, bool nonTransferable) internal virtual {
        _nonTransferableTokens[id] = nonTransferable;
        emit ERC6909NonTransferableUpdated(id, nonTransferable);
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - if `from` is the zero address, `to` must not be the zero address (minting).
     * - if `to` is the zero address, `from` must not be the zero address (burning).
     * - if both `from` and `to` are non-zero, token `id` must be transferable.
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `amount`.
     * - if `from` and `to` are the same, it does nothing.
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
    {
        if (from != address(0) && to != address(0) && _nonTransferableTokens[id]) {
            revert ERC6909NonTransferableToken(id);
        }
        super._update(from, to, id, amount);
    }
}
