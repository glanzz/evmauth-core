// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @dev Mixin providing role-based access control and pausability for token contracts.
 * This contract extends OpenZeppelin's AccessControlDefaultAdminRulesUpgradeable to manage roles with a
 * time-delayed admin role transfer mechanism. It also integrates pausability features to allow
 * authorized accounts to pause and unpause contract operations.
 */
abstract contract TokenAccessControl is AccessControlDefaultAdminRulesUpgradeable, PausableUpgradeable {
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
     * @dev Role required to modify the treasury address.
     */
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Status indicating an account should not be allowed to purchase, transfer, or receive tokens.
     */
    bytes32 public constant ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");

    /**
     * @dev Status indicating an account is no longer frozen.
     */
    bytes32 public constant ACCOUNT_UNFROZEN_STATUS = keccak256("ACCOUNT_UNFROZEN_STATUS");

    // Account => AccountStatus mapping (to track frozen accounts)
    mapping(address => bool) private _frozenAccounts;

    // Array of frozen accounts (to track all frozen accounts)
    address[] private _frozenList;

    /**
     * @dev Emitted when an address is frozen, unfrozen, added to, or removed from the allowlist.
     */
    event AccountStatusUpdate(address indexed account, bytes32 indexed status);

    /**
     * @dev Error indicating an account is frozen and cannot perform the requested operation.
     */
    error ERC6909AccessControlAccountFrozen(address account);

    /**
     * @dev Error indicating an invalid address was provided for access control operations.
     */
    error ERC6909AccessControlInvalidAddress(address account);

    /**
     * @dev Modifier to check if an `account` is not frozen.
     * If the account is frozen, it reverts with an `ERC6909AccessControlAccountFrozen` error.
     */
    modifier notFrozen(address account) {
        if (_frozenAccounts[account]) {
            revert ERC6909AccessControlAccountFrozen(account);
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     */
    function __TokenAccessControl_init(uint48 initialDelay, address initialDefaultAdmin) public onlyInitializing {
        __AccessControlDefaultAdminRules_init(initialDelay, initialDefaultAdmin);
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenAccessControl_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlDefaultAdminRulesUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Check if an `account` address is frozen.
     * A frozen account cannot purchase, transfer, or receive tokens.
     *
     * @param account The address of the account to check.
     * @return bool indicating whether the account is frozen.
     */
    function isFrozen(address account) external view virtual returns (bool) {
        return _frozenAccounts[account];
    }

    /**
     * @dev Get the full list of frozen accounts.
     *
     * @return address[] An array of addresses that are frozen.
     */
    function frozenAccounts() external view virtual returns (address[] memory) {
        return _frozenList;
    }

    /**
     * @dev Freezes an `account`, preventing it from purchasing, transferring, or receiving tokens.
     * If the account is already frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_FROZEN_STATUS`.
     *
     * Requirements:
     * - The `account` cannot be the zero address.
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     *
     * @param account The address of the account to freeze.
     */
    function freezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        if (account == address(0)) {
            revert ERC6909AccessControlInvalidAddress(account);
        }
        if (!_frozenAccounts[account]) {
            _frozenAccounts[account] = true;
            _frozenList.push(account);
            emit AccountStatusUpdate(account, ACCOUNT_FROZEN_STATUS);
        }
    }

    /**
     * @dev Unfreezes an `account`, allowing it to purchase, transfer, and receive tokens again.
     * If the account is not frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_UNFROZEN_STATUS`.
     *
     * Requirements:
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     *
     * @param account The address of the account to unfreeze.
     */
    function unfreezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        if (_frozenAccounts[account]) {
            _frozenAccounts[account] = false;
            // Remove the account from the frozen list
            for (uint256 i = 0; i < _frozenList.length; i++) {
                if (_frozenList[i] == account) {
                    _frozenList[i] = _frozenList[_frozenList.length - 1]; // Replace with the last element
                    _frozenList.pop(); // Remove the last element
                    break;
                }
            }
            emit AccountStatusUpdate(account, ACCOUNT_UNFROZEN_STATUS);
        }
    }
}
