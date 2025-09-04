// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { ERC6909Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC6909/draft-ERC6909Upgradeable.sol";
import { ERC6909ContentURIUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/draft-ERC6909ContentURIUpgradeable.sol";
import { ERC6909MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC6909/extensions/draft-ERC6909MetadataUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

contract EVMAuth6909 is ERC6909MetadataUpgradeable, ERC6909ContentURIUpgradeable, EVMAuth {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        string memory uri_
    ) public virtual initializer {
        __EVMAuth6909_init(initialDelay, initialDefaultAdmin, initialTreasury, uri_);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     */
    function __EVMAuth6909_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        string memory uri_
    ) internal onlyInitializing {
        __EVMAuth_init(initialDelay, initialDefaultAdmin, initialTreasury);
        __EVMAuth6909_init_unchained(uri_);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     *
     * @param uri_ The URI for the contract; see also: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
     */
    function __EVMAuth6909_init_unchained(string memory uri_) internal onlyInitializing {
        _setContractURI(uri_);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC6909Upgradeable, AccessControlDefaultAdminRulesUpgradeable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // @inheritdoc TokenEphemeral
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909Upgradeable, IERC6909, TokenEphemeral)
        returns (uint256)
    {
        return TokenEphemeral.balanceOf(account, id);
    }

    /**
     * @dev Mints `amount` tokens of token type `id` to account `to`.
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
     * @param contractURI The contract URI to set.
     */
    function setContractURI(string memory contractURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setContractURI(contractURI);
    }

    /**
     * @dev Sets the content URI for a given token `id`.
     *
     * @param id The token ID to set the content URI for.
     * @param contentURI The content URI to set.
     */
    function setTokenURI(uint256 id, string memory contentURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenURI(id, contentURI);
    }

    /**
     * @dev Sets the metadata for a given token `id`.
     *
     * @param id The token ID to set metadata for.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param decimals The decimals of the token.
     */
    function setTokenMetadata(uint256 id, string memory name, string memory symbol, uint8 decimals)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
    {
        _setName(id, name);
        _setSymbol(id, symbol);
        _setDecimals(id, decimals);
    }

    /// @inheritdoc TokenPurchasable
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        _mint(to, id, amount);
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Reverts with {InvalidSelfTransfer} if `from` and `to` are the same address.
     * Reverts with {InvalidZeroValueTransfer} if any of the `values` is zero.
     *
     * Emits a {Transfer} event.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param id The identifier of the token type to transfer.
     * @param amount The number of tokens to transfer.
     */
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override whenNotPaused {
        // Check if the sender and receiver are the same
        if (from == to) {
            revert InvalidSelfTransfer(from);
        }

        // Check if the amount is zero
        if (amount == 0) {
            revert InvalidZeroValueTransfer();
        }

        super._update(from, to, id, amount);
    }
}
