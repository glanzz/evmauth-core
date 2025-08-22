// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TokenAccessControl} from "src/common/TokenAccessControl.sol";
import {TokenNonTransferable} from "src/common/TokenNonTransferable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract consolidates ERC1155 with the Supply and URIStorage extensions.
 * It also integrates role-based access control and non-transferable token features.
 */
contract ERC1155X is ERC1155Supply, ERC1155URIStorage, TokenNonTransferable, TokenAccessControl {
    /**
     * @dev Error thrown when a transfer is attempted with the same sender and recipient addresses.
     */
    error ERC1155InvalidSelfTransfer(address sender);

    /**
     * @dev Error thrown when a transfer is attempted with a zero value `amount`.
     */
    error ERC1155InvalidZeroValueTransfer();

    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The base URI for token metadata.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        TokenAccessControl(initialDelay, initialDefaultAdmin)
        ERC1155(uri_)
    {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, TokenAccessControl)
        returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId) || TokenAccessControl.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155URIStorage
    function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return ERC1155URIStorage.uri(tokenId);
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
     * @param data Additional data with no specified format.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @dev Mints multiple token types to a single account.
     *
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     *
     * @param to The address to mint tokens to.
     * @param ids The token IDs to mint.
     * @param amounts The amounts of each token to mint.
     * @param data Additional data with no specified format.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
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
     * @dev Burns multiple token types from a single account.
     *
     * Requirements:
     * - The caller must have the `BURNER_ROLE`.
     *
     * @param from The address to burn tokens from.
     * @param ids The token IDs to burn.
     * @param amounts The amounts of each token to burn.
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external onlyRole(BURNER_ROLE) {
        _burnBatch(from, ids, amounts);
    }

    /**
     * @dev Sets the base URI for all tokens.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param baseURI The base URI to set.
     */
    function setBaseURI(string memory baseURI) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setBaseURI(baseURI);
    }

    /**
     * @dev Sets the URI for a specific token ID.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param tokenId The token ID to set the URI for.
     * @param tokenURI The URI to set.
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setURI(tokenId, tokenURI);
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
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * Emits a {TransferSingle} event, or a {TransferBatch} event if `ids` contains multiple values.
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
        denyBatchTransferIfAnyNonTransferable(from, to, ids)
    {
        // Check if the sender and receiver are the same
        if (from == to) {
            revert ERC1155InvalidSelfTransfer(from);
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
