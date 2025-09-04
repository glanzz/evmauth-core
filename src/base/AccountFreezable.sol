// SPDX-License-Identifier: MIT

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

pragma solidity ^0.8.24;

/**
 * @dev Abstract contract that allows freezing and unfreezing of accounts.
 */
abstract contract AccountFreezable is Initializable {
    /**
     * @dev Status indicating an account should not be allowed to purchase, transfer, or receive tokens.
     */
    bytes32 public constant ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");

    /**
     * @dev Status indicating an account is no longer frozen.
     */
    bytes32 public constant ACCOUNT_UNFROZEN_STATUS = keccak256("ACCOUNT_UNFROZEN_STATUS");

    /// @custom:storage-location erc7201:accountfreezable.storage.AccountFreezable
    struct AccountFreezableStorage {
        // Account => AccountStatus mapping (to track frozen accounts)
        mapping(address => bool) frozenAccounts;
        // Array of frozen accounts (to track all frozen accounts)
        address[] frozenList;
    }

    /**
     * @dev Storage location for the `AccountFreezable` contract, as defined by EIP-7201.
     *
     * This is a keccak-256 hash of a unique string, minus 1, and then rounded down to the nearest
     * multiple of 256 bits (32 bytes) to avoid potential storage slot collisions with other
     * upgradeable contracts that may be added to the same deployment.
     *
     * keccak256(abi.encode(uint256(keccak256("accountfreezable.storage.AccountFreezable")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 private constant AccountFreezableStorageLocation =
        0xa095fe5a3c31691ae0832631cef3701285d36b2af1972f4c23463476b0353a00;

    /**
     * @dev Returns the the storage struct for the `AccountFreezable` contract.
     */
    function _getAccountFreezableStorage() private pure returns (AccountFreezableStorage storage $) {
        assembly {
            $.slot := AccountFreezableStorageLocation
        }
    }

    /**
     * @dev Emitted when an address is frozen, unfrozen, added to, or removed from the allowlist.
     */
    event AccountStatusUpdated(address indexed account, bytes32 indexed status);

    /**
     * @dev Error indicating an account is frozen and cannot perform the requested operation.
     */
    error AccountFrozen(address account);

    /**
     * @dev Error indicating an invalid address was provided for access control operations.
     */
    error InvalidAddress(address account);

    /**
     * @dev Modifier to revert if `account` is frozen.
     */
    modifier notFrozen(address account) {
        AccountFreezableStorage storage $ = _getAccountFreezableStorage();
        if ($.frozenAccounts[account]) revert AccountFrozen(account);
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __AccountFreezable_init() internal onlyInitializing { }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __AccountFreezable_init_unchained() internal onlyInitializing { }

    /**
     * @dev Check if an `account` address is frozen.
     * A frozen account cannot purchase, transfer, or receive tokens.
     *
     * @param account The address of the account to check.
     * @return bool indicating whether the account is frozen.
     */
    function isFrozen(address account) external view virtual returns (bool) {
        AccountFreezableStorage storage $ = _getAccountFreezableStorage();
        return $.frozenAccounts[account];
    }

    /**
     * @dev Get the full list of frozen accounts.
     *
     * @return address[] An array of addresses that are frozen.
     */
    function frozenAccounts() external view virtual returns (address[] memory) {
        AccountFreezableStorage storage $ = _getAccountFreezableStorage();
        return $.frozenList;
    }

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
    function _freezeAccount(address account) internal virtual {
        if (account == address(0)) revert InvalidAddress(account);

        AccountFreezableStorage storage $ = _getAccountFreezableStorage();

        if ($.frozenAccounts[account]) return; // Account is already frozen, do nothing

        $.frozenAccounts[account] = true;
        $.frozenList.push(account);

        emit AccountStatusUpdated(account, ACCOUNT_FROZEN_STATUS);
    }

    /**
     * @dev Unfreezes an `account`, allowing it to purchase, transfer, and receive tokens again.
     * If the account is not frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_UNFROZEN_STATUS`.
     *
     * @param account The address of the account to unfreeze.
     */
    function _unfreezeAccount(address account) internal virtual {
        AccountFreezableStorage storage $ = _getAccountFreezableStorage();

        if (!$.frozenAccounts[account]) return; // Account is not frozen, do nothing

        $.frozenAccounts[account] = false;

        // Remove the account from the frozen list
        for (uint256 i = 0; i < $.frozenList.length; i++) {
            if ($.frozenList[i] == account) {
                $.frozenList[i] = $.frozenList[$.frozenList.length - 1]; // Replace with the last element
                $.frozenList.pop(); // Remove the last element
                break;
            }
        }

        emit AccountStatusUpdated(account, ACCOUNT_UNFROZEN_STATUS);
    }
}
