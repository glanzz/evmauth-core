// SPDX-License-Identifier: MIT

import { TokenAccessControl } from "src/base/TokenAccessControl.sol";
import { TokenEnumerable } from "src/base/TokenEnumerable.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { TokenTransferable } from "src/base/TokenTransferable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

pragma solidity ^0.8.24;

abstract contract EVMAuth is
    TokenAccessControl,
    TokenEnumerable,
    TokenEphemeral,
    TokenPurchasable,
    TokenTransferable,
    UUPSUpgradeable
{
    /**
     * @dev Configuration for an EVM authentication token type.
     *
     * @param price The price of the token, in whichever currency the contract is configured to use.
     * @param ttl The time-to-live (TTL) of the token, in seconds.
     * @param transferable Whether the token is transferable between addresses.
     */
    struct EVMAuthTokenConfig {
        uint256 price;
        uint256 ttl;
        bool transferable;
    }

    /**
     * @dev Details about an EVM authentication token type, including its ID and configuration.
     *
     * @param id The ID of the token type.
     * @param config The configuration of the token type, including its price, TTL, and transferability.
     */
    struct EVMAuthToken {
        uint256 id;
        EVMAuthTokenConfig config;
    }

    /**
     * @dev Emitted when a token's configuration is created or updated.
     */
    event EVMAuthTokenConfigured(uint256 indexed id, EVMAuthTokenConfig config);

    /**
     * @dev Error thrown when a transfer is attempted with the same sender and recipient addresses.
     */
    error InvalidSelfTransfer(address sender);

    /**
     * @dev Error thrown when a transfer is attempted with a zero value `amount`.
     */
    error InvalidZeroValueTransfer();

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __EVMAuth_init(uint48 initialDelay, address initialDefaultAdmin, address payable initialTreasury)
        internal
        onlyInitializing
    {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
        __TokenEnumerable_init();
        __TokenPurchasable_init(initialTreasury);
        __EVMAuth_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __EVMAuth_init_unchained() internal onlyInitializing { }

    /**
     * @dev Returns the configuration of a given token `id`.
     *
     * @param id The ID of the token to query.
     * @return The configuration of the token, including its price, TTL, and transferability
     */
    function tokenConfig(uint256 id) external view virtual tokenExists(id) returns (EVMAuthToken memory) {
        return EVMAuthToken({
            id: id,
            config: EVMAuthTokenConfig({ price: tokenPrice(id), ttl: tokenTTL(id), transferable: isTransferable(id) })
        });
    }

    /**
     * @dev Returns the configurations of multiple token `ids`.
     *
     * @param ids The IDs of the tokens to query.
     * @return configs An array of token configurations, each including its ID, price, TTL, and transferability
     */
    function tokenConfigs(uint256[] calldata ids)
        external
        view
        virtual
        allTokensExist(ids)
        returns (EVMAuthToken[] memory configs)
    {
        configs = new EVMAuthToken[](ids.length);
        if (ids.length == 0) {
            return configs;
        }

        for (uint256 i = 0; i < ids.length; i++) {
            configs[i] = EVMAuthToken({
                id: ids[i],
                config: EVMAuthTokenConfig({
                    price: tokenPrice(ids[i]),
                    ttl: tokenTTL(ids[i]),
                    transferable: isTransferable(ids[i])
                })
            });
        }

        return configs;
    }

    /**
     * @dev Returns the price of a given token `id`.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * @param id The ID of the token to query.
     * @return The price of the token, in whichever currency the contract is configured to use.
     */
    function tokenPrice(uint256 id) public view virtual override tokenExists(id) returns (uint256) {
        return TokenPurchasable.tokenPrice(id);
    }

    /**
     * @dev Returns the time-to-live (TTL) of a given token `id`, in seconds.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * @param id The ID of the token to query.
     * @return The TTL of the token, in seconds.
     */
    function tokenTTL(uint256 id) public view virtual override tokenExists(id) returns (uint256) {
        return TokenEphemeral.tokenTTL(id);
    }

    /**
     * @dev Returns whether a given token `id` is transferable.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * @param id The ID of the token to query.
     * @return True if the token is transferable, false otherwise.
     */
    function isTransferable(uint256 id) public view virtual override tokenExists(id) returns (bool) {
        return TokenTransferable.isTransferable(id);
    }

    /**
     * @dev Creates a new token type with the given configuration.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful creation.
     *
     * @param config The configuration for the new token type, including price, TTL, and transferability.
     * @return id The ID of the newly created token type.
     */
    function createToken(EVMAuthTokenConfig calldata config)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
        returns (uint256 id)
    {
        return _createToken(config);
    }

    /**
     * @dev Updates the configuration of an existing token type.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful update.
     *
     * @param id The ID of the token type to update.
     * @param config The new configuration for the token type, including price, TTL, and transferability.
     */
    function updateToken(uint256 id, EVMAuthTokenConfig calldata config)
        external
        virtual
        onlyRole(TOKEN_MANAGER_ROLE)
    {
        _updateToken(id, config);
    }

    /**
     * @dev Sets the price of a given token `id`.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful update.
     *
     * @param id The token ID to configure.
     * @param price The new price for the token.
     */
    function setPrice(uint256 id, uint256 price) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setPrice(id, price);

        emit EVMAuthTokenConfigured(
            id, EVMAuthTokenConfig({ price: price, ttl: tokenTTL(id), transferable: isTransferable(id) })
        );
    }

    /**
     * @dev Sets the time-to-live (TTL) of a given token `id`.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful update.
     *
     * @param id The token ID to configure.
     * @param ttl The new TTL for the token, in seconds.
     */
    function setTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTTL(id, ttl);

        emit EVMAuthTokenConfigured(
            id, EVMAuthTokenConfig({ price: tokenPrice(id), ttl: ttl, transferable: isTransferable(id) })
        );
    }

    /**
     * @dev Sets the transferability of a given token `id`.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful update.
     *
     * @param id The token ID to configure.
     * @param transferable True if the token should be transferable, false otherwise.
     */
    function setTransferable(uint256 id, bool transferable) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTransferable(id, transferable);

        emit EVMAuthTokenConfigured(
            id, EVMAuthTokenConfig({ price: tokenPrice(id), ttl: tokenTTL(id), transferable: transferable })
        );
    }

    /**
     * @dev Internal function to create a new token type with the given configuration.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful creation.
     *
     * @param config The configuration for the new token type, including price, TTL, and transferability.
     * @return id The ID of the newly created token type.
     */
    function _createToken(EVMAuthTokenConfig calldata config) internal virtual returns (uint256 id) {
        id = _claimNextTokenID();

        _setPrice(id, config.price);
        _setTTL(id, config.ttl);
        _setTransferable(id, config.transferable);

        emit EVMAuthTokenConfigured(id, config);

        return id;
    }

    /**
     * @dev Internal function to update the configuration of an existing token type.
     *
     * Reverts if the token `id` does has not been created yet.
     *
     * Emits an {EVMAuthTokenConfigured} event upon successful update.
     *
     * @param id The ID of the token type to update.
     * @param config The new configuration for the token type, including price, TTL, and transferability.
     */
    function _updateToken(uint256 id, EVMAuthTokenConfig calldata config) internal virtual tokenExists(id) {
        _setPrice(id, config.price);
        _setTTL(id, config.ttl);
        _setTransferable(id, config.transferable);

        emit EVMAuthTokenConfigured(id, config);
    }

    // @inheritdoc TokenPurchasable
    function _setPrice(uint256 id, uint256 price) internal virtual override tokenExists(id) {
        TokenPurchasable._setPrice(id, price);
    }

    // @inheritdoc TokenEphemeral
    function _setTTL(uint256 id, uint256 ttl) internal virtual override tokenExists(id) {
        TokenEphemeral._setTTL(id, ttl);
    }

    // @inheritdoc TokenTransferable
    function _setTransferable(uint256 id, bool transferable) internal virtual override tokenExists(id) {
        super._setTransferable(id, transferable);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller is not authorized.
    }
}
