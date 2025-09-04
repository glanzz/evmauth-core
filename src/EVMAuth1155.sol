// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155URIStorageUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract EVMAuth1155 is ERC1155URIStorageUpgradeable, EVMAuth {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        string memory uri_
    ) public virtual initializer {
        __EVMAuth1155_init(initialDelay, initialDefaultAdmin, initialTreasury, uri_);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param uri_ The base URI for all token types; see also: https://eips.ethereum.org/EIPS/eip-1155#metadata
     */
    function __EVMAuth1155_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        string memory uri_
    ) internal onlyInitializing {
        __ERC1155_init(uri_);
        __ERC1155URIStorage_init();
        __EVMAuth_init(initialDelay, initialDefaultAdmin, initialTreasury);
        __EVMAuth1155_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth1155_init_unchained() internal onlyInitializing { }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155URIStorageUpgradeable
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
    }

    // @inheritdoc TokenEphemeral
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC1155Upgradeable, TokenEphemeral)
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
     * @param data Additional data with no specified format.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @dev Mints multiple token types to a single account.
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
     * @param baseURI The base URI to set.
     */
    function setBaseURI(string memory baseURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setBaseURI(baseURI);
    }

    /**
     * @dev Sets the URI for a given token `id`.
     *
     * @param id The token ID to set the URI for.
     * @param tokenURI The URI to set.
     */
    function setTokenURI(uint256 id, string memory tokenURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setURI(id, tokenURI);
    }

    /// @inheritdoc TokenPurchasable
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        _mint(to, id, amount, "");
    }

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value: `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * Reverts with {InvalidSelfTransfer} if `from` and `to` are the same address.
     * Reverts with {InvalidZeroValueTransfer} if any of the `values` is zero.
     *
     * Emits a {TransferSingle} event, or a {TransferBatch} event if `ids` contains multiple values.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param ids The identifiers of the token types to transfer.
     * @param values The numbers of tokens to transfer.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
        whenNotPaused
        allTokensExist(ids)
        allTokensTransferable(from, to, ids)
    {
        // Check if the sender and receiver are the same
        if (from == to) {
            revert InvalidSelfTransfer(from);
        }

        // Check if any values are zero
        for (uint256 i = 0; i < values.length; ++i) {
            if (values[i] == 0) {
                revert InvalidZeroValueTransfer();
            }
        }

        super._update(from, to, ids, values);
    }
}
