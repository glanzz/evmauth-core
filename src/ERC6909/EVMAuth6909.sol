// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenAccessControl } from "src/common/TokenAccessControl.sol";
import { TokenBaseConfig } from "src/common/TokenBaseConfig.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC6909Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC6909/draft-ERC6909Upgradeable.sol";
import { ERC6909ContentURIUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/draft-ERC6909ContentURIUpgradeable.sol";
import { ERC6909MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/draft-ERC6909MetadataUpgradeable.sol";
import { ERC6909TokenSupplyUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/draft-ERC6909TokenSupplyUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract combines {ERC6909Upgradeable} with the {ERC6909ContentURIUpgradeable},
 * {ERC6909MetadataUpgradeable}, and {ERC6909TokenSupplyUpgradeable} extensions, as well as
 * the {TokenAccessControl} and {TokenBaseConfig} mixins.
 */
contract EVMAuth6909 is
    ERC6909ContentURIUpgradeable,
    ERC6909MetadataUpgradeable,
    ERC6909TokenSupplyUpgradeable,
    TokenBaseConfig,
    TokenAccessControl,
    UUPSUpgradeable
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
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     */
    function initialize(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        virtual
        initializer
    {
        __EVMAuth6909_init(initialDelay, initialDefaultAdmin, uri_);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     */
    function __EVMAuth6909_init(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        onlyInitializing
    {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
        _setContractURI(uri_);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth6909_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC6909Upgradeable, IERC165, TokenAccessControl)
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
     * @dev Configures a token with the provided configuration.
     * If id is 0, assigns the next sequential token ID.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to configure (0 for next sequential ID).
     * @param config The configuration to apply.
     * @return tokenId The ID of the configured token.
     */
    function configureToken(uint256 id, TokenConfig memory config)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
        returns (uint256 tokenId)
    {
        return _configureToken(id, config);
    }

    /**
     * @dev Batch configures multiple tokens.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param ids Array of token IDs (0 for next sequential ID).
     * @param configs Array of configurations to apply.
     * @return tokenIds Array of configured token IDs.
     */
    function batchConfigureTokens(uint256[] memory ids, TokenConfig[] memory configs)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
        returns (uint256[] memory tokenIds)
    {
        require(ids.length == configs.length, "EVMAuth6909: arrays length mismatch");
        tokenIds = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            tokenIds[i] = this.configureToken(ids[i], configs[i]);
        }

        return tokenIds;
    }

    /**
     * @dev Sets whether a token ID is transferable.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     *
     * @param id The token ID to configure.
     * @param transferable Whether the token should be transferable.
     */
    function setTransferability(uint256 id, bool transferable) external onlyRole(TOKEN_MANAGER_ROLE) {
        _setTransferability(id, transferable);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller does not have the UPGRADE_MANAGER_ROLE
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
        override(ERC6909Upgradeable, ERC6909TokenSupplyUpgradeable)
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
