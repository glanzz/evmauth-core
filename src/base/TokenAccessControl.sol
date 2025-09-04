// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { AccountFreezable } from "src/base/AccountFreezable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev Abstract contract that provides a standardized access control mechanism for token contracts,
 * including roles for upgrade management, access management, token management, minting, burning,
 * and treasury management. It also includes account freezing and token pausing capabilities via the
 * {AccountFreezable} and {PausableUpgradeable} extensions.
 */
abstract contract TokenAccessControl is
    AccessControlDefaultAdminRulesUpgradeable,
    AccountFreezable,
    PausableUpgradeable
{
    /**
     * @dev Role required to upgrade the contract.
     */
    bytes32 public constant UPGRADE_MANAGER_ROLE = keccak256("UPGRADE_MANAGER_ROLE");

    /**
     * @dev Role required to pause/un-pause the contract and freeze/un-freeze accounts.
     */
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");

    /**
     * @dev Role required to manage token configuration, metadata, and content URIs.
     */
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    /**
     * @dev Role required to mint new tokens.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Role required to burn tokens.
     */
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Role required to modify the treasury address (if applicable).
     */
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     */
    function __TokenAccessControl_init(uint48 initialDelay, address initialDefaultAdmin) internal onlyInitializing {
        __AccessControlDefaultAdminRules_init(initialDelay, initialDefaultAdmin);
        __TokenAccessControl_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenAccessControl_init_unchained() internal onlyInitializing { }

    /**
     * @dev Freezes an `account`, preventing it from purchasing, transferring, or receiving tokens.
     * If the account is already frozen, this function does nothing.
     *
     * Reverts with {InvalidAddress} if the `account` is the zero address.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_FROZEN_STATUS`.
     *
     * @param account The address of the account to freeze.
     */
    function freezeAccount(address account) external onlyRole(ACCESS_MANAGER_ROLE) {
        _freezeAccount(account);
    }

    /**
     * @dev Unfreezes an `account`, allowing it to purchase, transfer, and receive tokens again.
     * If the account is not frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_UNFROZEN_STATUS`.
     *
     * @param account The address of the account to unfreeze.
     */
    function unfreezeAccount(address account) external onlyRole(ACCESS_MANAGER_ROLE) {
        _unfreezeAccount(account);
    }
}
