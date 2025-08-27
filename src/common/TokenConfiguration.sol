// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Mixin to add base configuration functionality to token contracts.
 * Provides sequential token ID tracking, transferability management, and a unified
 * configuration interface with hooks for extensibility.
 */
abstract contract TokenConfiguration is ContextUpgradeable {
    /**
     * @dev Data structure for unified token configuration.
     *
     * Different contract implementations use different fields:
     * - Base contracts: Only use `isTransferable`
     * - With TokenPrice: Also use `price` field (0 = not for sale)
     * - With TokenExpiry: Also use `ttl` field (0 = never expires)
     *
     * Unused fields are set to zero.
     */
    struct TokenConfig {
        bool isTransferable; // Whether the token can be transferred
        uint256 price; // Price for purchase (0 = not for sale, for use with TokenPrice mixin)
        uint256 ttl; // Time-to-live in seconds (0 = never expires, for use with TokenExpiry mixin)
    }

    /**
     * @dev Mapping to track token configurations.
     */
    mapping(uint256 => TokenConfig) private _tokenConfigs;

    /**
     * @dev The next token ID to be assigned when configuring a new token.
     */
    uint256 public nextTokenId;

    /**
     * @dev Emitted when the transferability of a token `id` is updated.
     */
    event TokenTransferabilityUpdated(address caller, uint256 indexed id, bool isTransferable);

    /**
     * @dev Emitted when a token is configured.
     */
    event TokenConfigUpdated(address caller, uint256 indexed id, TokenConfig config);

    /**
     * @dev Error thrown when a transfer is attempted for a non-transferable token `id`.
     */
    error TokenIsNonTransferable(uint256 id);

    /**
     * @dev Error thrown when an operation is attempted on a non-existent token.
     */
    error TokenDoesNotExist(uint256 id);

    /**
     * @dev Modifier to ensure a token exists.
     * @param id The token ID to check.
     */
    modifier requireTokenExists(uint256 id) {
        if (!tokenExists(id)) {
            revert TokenDoesNotExist(id);
        }
        _;
    }

    /**
     * @dev Modifier to check if a token `id` can be transferred between accounts,
     * while also ensuring that neither the sender nor the receiver is the zero address.
     *
     * Reverts with {TokenConfiguration} error if the token is non-transferable.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param id The identifier of the token type to check.
     * @notice This modifier should be applied to a core function that handle single token transfers,
     * like the `_update` method in OpenZeppelin's {ERC6909} contract.
     */
    modifier denyTransferIfNonTransferable(address from, address to, uint256 id) {
        if (!tokenExists(id)) {
            revert TokenDoesNotExist(id);
        }
        if (from != address(0) && to != address(0) && _tokenConfigs[id].isTransferable == false) {
            revert TokenIsNonTransferable(id);
        }
        _;
    }

    /**
     * @dev Modifier to check if a batch of token `ids` can be transferred between accounts,
     * while also ensuring that neither the sender nor the receiver is the zero address.
     * Reverts with {TokenConfiguration} error if any token in the batch is non-transferable.
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param ids The identifiers of the token types to check.
     * @notice This modifier should be applied to a core function that handle batch token transfers,
     * like the `_update` method in OpenZeppelin's {ERC1155} contract.
     */
    modifier denyBatchTransferIfAnyNonTransferable(address from, address to, uint256[] memory ids) {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (!tokenExists(ids[i])) {
                    revert TokenDoesNotExist(ids[i]);
                }
                if (from != address(0) && to != address(0) && _tokenConfigs[ids[i]].isTransferable == false) {
                    revert TokenIsNonTransferable(ids[i]);
                }
            }
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenConfiguration_init() public onlyInitializing {
        __TokenConfiguration_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenConfiguration_init_unchained() public onlyInitializing {
        nextTokenId = 1; // Start token IDs at 1
    }

    /**
     * @dev Checks if a token ID exists (has been configured).
     *
     * @param id The token ID to check.
     * @return bool indicating whether the token exists.
     */
    function tokenExists(uint256 id) public view virtual returns (bool) {
        return id > 0 && id < nextTokenId;
    }

    /**
     * @dev Returns the configuration of a specific token `id`.
     *
     * @param id The identifier of the token type to get the configuration for.
     * @return TokenConfig struct containing the configuration of the token `id`.
     */
    function tokenConfig(uint256 id) public view virtual requireTokenExists(id) returns (TokenConfig memory) {
        return _tokenConfigs[id];
    }

    /**
     * @dev Check if a token `id` can be transferred between accounts.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the token `id` is transferable.
     */
    function isTransferable(uint256 id) public view virtual requireTokenExists(id) returns (bool) {
        return _tokenConfigs[id].isTransferable;
    }

    /**
     * @dev Returns the price of a specific token `id`.
     * Returns 0 if the token is not for sale.
     *
     * @param id The identifier of the token type to get the price for.
     * @return uint256 representing the price of the token `id`.
     */
    function priceOf(uint256 id) public view virtual requireTokenExists(id) returns (uint256) {
        return _tokenConfigs[id].price;
    }

    /**
     * @dev Returns the TTL (time-to-live) of a specific token `id`.
     * Returns 0 if the token never expires.
     *
     * @param id The identifier of the token type to get the TTL for.
     * @return uint256 representing the TTL of the token `id`.
     */
    function ttlOf(uint256 id) public view virtual requireTokenExists(id) returns (uint256) {
        return _tokenConfigs[id].ttl;
    }

    /**
     * @dev Creates a new token with the given configuration, using the next sequential token ID.
     * The value of `_nextTokenId` is incremented after assignment.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * @param config The configuration for the new token.
     * @return tokenId The ID of the configured token.
     */
    function _newToken(TokenConfig memory config) internal virtual returns (uint256) {
        uint256 id = nextTokenId;
        _tokenConfigs[id] = config;
        nextTokenId++;

        emit TokenConfigUpdated(_msgSender(), id, config);

        return id;
    }

    /**
     * @dev Sets the transferability of a specific token `id`.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * @param id The token ID to configure.
     * @param transferable True if the token should be transferable, false otherwise.
     */
    function _setTransferable(uint256 id, bool transferable) internal virtual requireTokenExists(id) {
        _tokenConfigs[id].isTransferable = transferable;

        emit TokenConfigUpdated(_msgSender(), id, _tokenConfigs[id]);
    }

    /**
     * @dev Sets the price of a specific token `id`.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * @param id The identifier of the token type for which to set the price.
     * @param price The price to set for the token type (0 to disable purchases).
     */
    function _setPrice(uint256 id, uint256 price) internal virtual requireTokenExists(id) {
        _tokenConfigs[id].price = price;

        emit TokenConfigUpdated(_msgSender(), id, _tokenConfigs[id]);
    }

    /**
     * @dev Sets the TTL (time-to-live) of a specific token `id`.
     *
     * Emits a {TokenConfigUpdated} event.
     *
     * @param id The identifier of the token type for which to set the TTL.
     * @param ttl The TTL to set for the token type (0 means the token never expires).
     */
    function _setTTL(uint256 id, uint256 ttl) internal virtual requireTokenExists(id) {
        _tokenConfigs[id].ttl = ttl;

        emit TokenConfigUpdated(_msgSender(), id, _tokenConfigs[id]);
    }
}
