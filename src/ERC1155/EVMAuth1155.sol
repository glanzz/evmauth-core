// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenAccessControl } from "src/common/TokenAccessControl.sol";
import { TokenConfiguration } from "src/common/TokenConfiguration.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { ERC1155URIStorageUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features.
 * This contract combines {ERC1155Upgradeable} with the {ERC1155SupplyUpgradeable} and
 * {ERC1155URIStorageUpgradeable} extensions, as well as the {TokenAccessControl} and
 * {TokenConfiguration} mixins.
 */
contract EVMAuth1155 is
    ERC1155SupplyUpgradeable,
    ERC1155URIStorageUpgradeable,
    TokenConfiguration,
    TokenAccessControl,
    UUPSUpgradeable
{
    /**
     * @dev Error thrown when a transfer is attempted with the same sender and recipient addresses.
     */
    error ERC1155InvalidSelfTransfer(address sender);

    /**
     * @dev Error thrown when a transfer is attempted with a zero value `amount`.
     */
    error ERC1155InvalidZeroValueTransfer();

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
        initializer
    {
        __EVMAuth1155_init(initialDelay, initialDefaultAdmin, uri_);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     */
    function __EVMAuth1155_init(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        onlyInitializing
    {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
        __ERC1155_init(uri_);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth1155_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, TokenAccessControl)
        returns (bool)
    {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || TokenAccessControl.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155URIStorageUpgradeable
    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
    }

    /**
     * @dev Creates a new token with the given configuration, using the next sequential token ID.
     * The value of `_nextTokenId` is incremented after assignment.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param config The configuration for the new token.
     * @return tokenId The ID of the configured token.
     */
    function newToken(TokenConfig memory config)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
        returns (uint256 tokenId)
    {
        return _newToken(config);
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
     * @dev Sets whether a token ID is transferable.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to configure.
     * @param transferable Whether the token should be transferable.
     */
    function setTransferable(uint256 id, bool transferable) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setTransferable(id, transferable);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller does not have the UPGRADE_MANAGER_ROLE
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
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
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
