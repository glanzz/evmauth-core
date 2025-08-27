// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Mixin to add base configuration functionality to token contracts.
 * Provides sequential token ID tracking, transferability management, and a unified
 * configuration interface with hooks for extensibility.
 */
abstract contract TokenBaseConfig is ContextUpgradeable {
    /**
     * @dev Data structure for unified token configuration.
     *
     * Different contract implementations use different fields:
     * - Base contracts: Only use `isTransferable`
     * - With TokenPrice: Also use `price` field (0 = not for sale)
     * - With TokenTTL: Also use `ttl` field (0 = never expires)
     *
     * Set unused fields to their zero values.
     */
    struct TokenConfig {
        bool isTransferable; // Whether the token can be transferred
        uint256 price; // Price for purchase (0 = not for sale, for use with TokenPrice mixin)
        uint256 ttl; // Time-to-live in seconds (0 = never expires, for use with TokenTTL mixin)
    }

    /**
     * @dev Mapping from token `id` to its non-transferable status.
     * If `true`, the token cannot be transferred between accounts.
     */
    mapping(uint256 => bool) private _nonTransferableTokens;

    /**
     * @dev The next token ID to be assigned when configuring a new token.
     */
    uint256 private _nextTokenId;

    /**
     * @dev Emitted when the transferability of a token `id` is updated.
     */
    event TokenTransferabilityUpdated(address caller, uint256 indexed id, bool isTransferable);

    /**
     * @dev Emitted when a token is configured.
     */
    event TokenConfigured(address caller, uint256 indexed id, TokenConfig config);

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
     * Reverts with {TokenBaseConfig} error if the token is non-transferable.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param id The identifier of the token type to check.
     * @notice This modifier should be applied to a core function that handle single token transfers,
     * like the `_update` method in OpenZeppelin's {ERC6909} contract.
     */
    modifier denyTransferIfNonTransferable(address from, address to, uint256 id) {
        if (from != address(0) && to != address(0) && _nonTransferableTokens[id]) {
            revert TokenIsNonTransferable(id);
        }
        _;
    }

    /**
     * @dev Modifier to check if a batch of token `ids` can be transferred between accounts,
     * while also ensuring that neither the sender nor the receiver is the zero address.
     * Reverts with {TokenBaseConfig} error if any token in the batch is non-transferable.
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param ids The identifiers of the token types to check.
     * @notice This modifier should be applied to a core function that handle batch token transfers,
     * like the `_update` method in OpenZeppelin's {ERC1155} contract.
     */
    modifier denyBatchTransferIfAnyNonTransferable(address from, address to, uint256[] memory ids) {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (_nonTransferableTokens[ids[i]]) {
                    revert TokenIsNonTransferable(ids[i]);
                }
            }
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenNonTransferable_init() public onlyInitializing {
        __TokenNonTransferable_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenNonTransferable_init_unchained() public onlyInitializing {
        _nextTokenId = 1; // Start token IDs at 1
    }

    /**
     * @dev Checks if a token ID exists (has been configured).
     *
     * @param id The token ID to check.
     * @return bool indicating whether the token exists.
     */
    function tokenExists(uint256 id) public view virtual returns (bool) {
        return id > 0 && id < _nextTokenId;
    }

    /**
     * @dev Returns the total number of token types that have been configured.
     *
     * @return The number of existing token types.
     */
    function totalTokenTypes() public view virtual returns (uint256) {
        return _nextTokenId > 0 ? _nextTokenId - 1 : 0;
    }

    /**
     * @dev Check if a token `id` can be transferred between accounts.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the token `id` is transferable.
     */
    function isTransferable(uint256 id) public view virtual returns (bool) {
        return !_nonTransferableTokens[id];
    }

    /**
     * @dev Returns the next token ID that will be assigned.
     */
    function nextTokenId() public view virtual returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Returns the complete configuration for multiple tokens.
     * This is useful for migration and bulk operations.
     *
     * @param ids Array of token IDs to get configurations for.
     * @return configs Array of TokenConfig structs.
     */
    function getTokenConfigurations(uint256[] memory ids) public view virtual returns (TokenConfig[] memory configs) {
        configs = new TokenConfig[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            configs[i] = _getTokenConfig(ids[i]);
        }
    }

    /**
     * @dev Sets the transferability of a specific token `id`.
     *
     * Emits a {TokenTransferabilityUpdated} event.
     *
     * Requirements:
     * - The caller must have the appropriate role (defined by inheriting contract).
     *
     * @param id The token ID to configure.
     * @param transferable Whether the token should be transferable.
     */
    function _setTransferability(uint256 id, bool transferable) internal virtual {
        _nonTransferableTokens[id] = !transferable;
        emit TokenTransferabilityUpdated(_msgSender(), id, transferable);
    }

    /**
     * @dev Configures a token with the given configuration.
     * If `id` is 0, assigns the next sequential token ID.
     * Returns the token ID that was configured.
     *
     * This base implementation only uses the `isTransferable` field from the config.
     * Derived contracts may use additional fields (price, ttl) through hooks.
     * Unused fields should be set to 0 or empty string.
     *
     * @param id The token ID to configure (0 for next sequential ID).
     * @param config The configuration to apply (base implementation only uses isTransferable).
     * @return tokenId The ID of the configured token.
     */
    function _configureToken(uint256 id, TokenConfig memory config) internal virtual returns (uint256 tokenId) {
        // Assign sequential ID if not specified
        if (id == 0) {
            tokenId = _nextTokenId++;
        } else {
            tokenId = id;
            // Update next token ID if needed
            if (tokenId >= _nextTokenId) {
                _nextTokenId = tokenId + 1;
            }
        }

        // Call before hook
        _beforeTokenConfiguration(tokenId, config);

        // Apply base configuration (transferability only)
        _setTransferability(tokenId, config.isTransferable);

        // Call after hook for additional configuration
        _afterTokenConfiguration(tokenId, config);

        emit TokenConfigured(_msgSender(), tokenId, config);

        return tokenId;
    }

    /**
     * @dev Hook called before token configuration.
     * Can be overridden to add validation or preprocessing.
     *
     * @param tokenId The token ID being configured.
     * @param config The configuration being applied.
     */
    function _beforeTokenConfiguration(uint256 tokenId, TokenConfig memory config) internal virtual {
        // Empty default implementation
    }

    /**
     * @dev Hook called after base token configuration.
     * Should be overridden by contracts that include additional mixins
     * to apply their specific configuration (e.g., price, TTL).
     *
     * @param tokenId The token ID that was configured.
     * @param config The configuration that was applied.
     */
    function _afterTokenConfiguration(uint256 tokenId, TokenConfig memory config) internal virtual {
        // Empty default implementation
    }

    /**
     * @dev Internal function to get the base configuration for a token.
     * Can be overridden by inheriting contracts to include additional config.
     *
     * @param id The token ID to get configuration for.
     * @return config The token configuration.
     */
    function _getTokenConfig(uint256 id) internal view virtual returns (TokenConfig memory config) {
        config.isTransferable = !_nonTransferableTokens[id];
        // Other fields (price, ttl) will be populated by overrides
    }
}
