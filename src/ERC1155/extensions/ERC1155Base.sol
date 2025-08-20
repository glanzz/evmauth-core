// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155Base} from "./IERC1155Base.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract consolidates ERC1155 with the Supply and URIStorage extensions.
 * It serves as a base contract for more complex implementations.
 */
abstract contract ERC1155Base is IERC1155Base, ERC1155Supply, ERC1155URIStorage, Pausable {
    // Token ID => is non-transferable mapping (tokens are transferable by default)
    mapping(uint256 => bool) private _nonTransferableTokens;

    // Errors
    error ERC1155NonTransferableToken(uint256 id);
    error ERC1155InvalidSelfTransfer(address sender);
    error ERC1155InvalidZeroValueTransfer();

    /**
     * @dev Constructor that sets the base URI for all tokens.
     * @param uri_ The base URI for all tokens.
     */
    constructor(string memory uri_) ERC1155(uri_) {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Base).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155Base
    function isTransferable(uint256 id) public view virtual returns (bool) {
        return !_nonTransferableTokens[id];
    }

    /// @inheritdoc IERC1155Base
    function totalSupply(uint256 id) public view virtual override(IERC1155Base, ERC1155Supply) returns (uint256) {
        return ERC1155Supply.totalSupply(id);
    }

    /// @inheritdoc IERC1155Base
    function totalSupply() public view virtual override(IERC1155Base, ERC1155Supply) returns (uint256) {
        return ERC1155Supply.totalSupply();
    }

    /// @inheritdoc IERC1155Base
    function exists(uint256 id) public view virtual override(IERC1155Base, ERC1155Supply) returns (bool) {
        return ERC1155Supply.exists(id);
    }

    /// @inheritdoc ERC1155URIStorage
    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155URIStorage, IERC1155MetadataURI)
        returns (string memory)
    {
        return ERC1155URIStorage.uri(tokenId);
    }

    /**
     * @dev Sets the non-transferable status of a specific token `id`.
     *
     * Emits a {ERC1155NonTransferableUpdated} event.
     *
     * Requirements:
     * - The caller must have the appropriate access control permissions.
     */
    function _setNonTransferable(uint256 id, bool nonTransferable) internal virtual {
        _nonTransferableTokens[id] = nonTransferable;
        emit ERC1155NonTransferableUpdated(id, nonTransferable);
    }

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     * - if `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     *   acceptance magic value.
     * - the `from` and `to` addresses must not be the same.
     * - if both `from` and `to` are non-zero, token `id` must be transferable.
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `amount`.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param ids The identifiers of the token types to transfer.
     * @param values The numbers of tokens to transfer.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155, ERC1155Supply)
        whenNotPaused
    {
        // Check if the sender and receiver are the same
        if (from == to) {
            revert ERC1155InvalidSelfTransfer(from);
        }

        // Check if this is a transfer and the token is non-transferable
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                if (_nonTransferableTokens[ids[i]]) {
                    revert ERC1155NonTransferableToken(ids[i]);
                }
            }
        }

        // Check if any values are zero
        for (uint256 i = 0; i < values.length; ++i) {
            if (values[i] == 0) {
                revert ERC1155InvalidZeroValueTransfer();
            }
        }

        super._update(from, to, ids, values);
    }
}
