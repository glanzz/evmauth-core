// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Mixin that provides time-to-live (TTL) functionality for token contracts.
 * Tokens can be configured to expire after a certain period, and the contract manages balance
 * records with expiration times automatically
 */
abstract contract TokenTTL is ContextUpgradeable {
    // Maximum BalanceRecord array size per address, per token ID
    uint256 public constant DEFAULT_MAX_BALANCE_RECORDS = 30;

    // Balance record data structure that ties an amount to an expiration time
    struct BalanceRecord {
        uint256 amount; // Balance that expires at `expiresAt`
        uint256 expiresAt; // Set to max value to indicate no expiration
    }

    // Data structure that holds the TTL (time-to-live) for a token and whether it has been set
    struct TTLConfig {
        bool isSet; // TTL can be 0, so we need a flag to indicate if it was intentionally set to 0
        uint256 ttl; // Seconds until expiration (if 0, the token never expires)
    }

    // Owner => Token ID => Array of balance records
    mapping(address owner => mapping(uint256 id => BalanceRecord[])) private _balanceRecords;

    // Token ID => token configuration (cannot be changed after being set)
    mapping(uint256 id => TTLConfig) private _ttlConfigs;

    /**
     * @dev Emitted when the TTL for a token `id` is set by `caller`.
     */
    event TTLUpdated(address caller, uint256 indexed id, uint256 ttl);

    /**
     * @dev Error thrown when deducting or transferring tokens from an account with insufficient funds.
     */
    error TokenTTLInsufficientBalance(address account, uint256 available, uint256 requested, uint256 id);

    /**
     * @dev Error thrown when trying to set the TTL for a token `id` that has already been set.
     * Once a TTL is set for a token `id`, it cannot be changed or removed.
     */
    error TokenTTLAlreadySet(uint256 id, uint256 ttl);

    /**
     * @dev Error thrown when trying to access the TTL of a token `id` that has not been set.
     */
    error TokenTLLNotSet(uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenTTL_init() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenTTL_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Returns the balance of a specific token `id` for a given `account`, excluding expired tokens.
     *
     * @param account The address of the account to check the balance for.
     * @param id The identifier of the token type to check the balance for.
     * @return The balance of the token `id` for the specified `account`, excluding expired tokens.
     */
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        BalanceRecord[] storage records = _balanceRecords[account][id];
        uint256 balance = 0;
        uint256 currentLength = records.length;

        for (uint256 i = 0; i < currentLength; i++) {
            if (records[i].expiresAt > block.timestamp) {
                balance += records[i].amount;
            }
        }

        return balance;
    }

    /**
     * @dev Returns the balance records array for a given account and token ID.
     *
     * @param account The address of the account.
     * @param id The identifier of the token type.
     * @return The array of balance records.
     */
    function balanceRecordsOf(address account, uint256 id) external view returns (BalanceRecord[] memory) {
        return _balanceRecords[account][id];
    }

    /**
     * @dev Returns true if the TTL for a specific token `id` has been set.
     * Once a TTL is set for a token `id`, it cannot be changed or removed. This is necessary because expiring
     * tokens are grouped into expiration time buckets, to prevent denial-of-service attacks based on unbounded
     * data storage.
     *
     * If the TTL is set to 0, it will still return true, as it indicates that the TTL was intentionally set to 0.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the TTL for the token `id` is set.
     */
    function isTTLSet(uint256 id) external view returns (bool) {
        return _ttlConfigs[id].isSet;
    }

    /**
     * @dev Returns the TTL (time-to-live) of a token `id` (in seconds).
     * If the TTL is set to 0, it means the token does not expire.
     *
     * Reverts if the token TTL has not yet been set.
     *
     * @param id The identifier of the token type to get the TTL for.
     * @return The TTL in seconds for the token `id`.
     */
    function ttlOf(uint256 id) external view returns (uint256) {
        if (!_ttlConfigs[id].isSet) {
            // We need to revert here, to prevent un-configured tokens from being treated as non-expiring
            revert TokenTLLNotSet(id);
        }

        return _ttlConfigs[id].ttl;
    }

    /**
     * @dev Returns the maximum number of balance records per address, per token ID.
     * Each balance record is a tuple of (amount, expiresAt), and each address/token pair has an array of them.
     * This is used to limit the number of balance records stored for each address and token ID, which helps
     * prevent unbounded storage growth and denial-of-service attacks that could cause balance record maintenance
     * operations to require excessive gas.
     *
     * When a token is minted or purchased, the expiration will be:
     * - Minimum: TTL seconds
     * - Maximum: TTL + (TTL / DEFAULT_MAX_BALANCE_RECORDS - 1) seconds
     *
     * This function can be overridden to change the maximum number of balance records.
     */
    function _maxBalanceRecords() internal view virtual returns (uint256) {
        return DEFAULT_MAX_BALANCE_RECORDS;
    }

    /**
     * @dev Insert or update a balance record for a given account and token `id`.
     * Maintains sorted order by expiration bucket (oldest to newest).
     * If a record with the same expiration already exists, it combines the amounts.
     *
     * @param account The address of the account to update.
     * @param id The identifier of the token type to update.
     * @param amount The amount to add to the balance record.
     * @param expiresAt The expiration time for the balance record.
     */
    function _addToBalanceRecord(address account, uint256 id, uint256 amount, uint256 expiresAt) internal {
        // First, prune expired records to free up space
        _pruneBalanceRecords(account, id);

        BalanceRecord[] storage records = _balanceRecords[account][id];
        uint256 currentLength = records.length;
        uint256 insertIndex = currentLength;

        // Find the correct position to insert (sorted by expiration)
        for (uint256 i = 0; i < currentLength; i++) {
            // Empty slot found
            if (records[i].amount == 0 && records[i].expiresAt == 0) {
                insertIndex = i;
                break;
            }
            // Found matching expiration - combine amounts
            if (records[i].expiresAt == expiresAt) {
                records[i].amount += amount;
                return;
            }
            // Found later expiration - insert before it
            if (records[i].expiresAt > expiresAt) {
                insertIndex = i;
                break;
            }
        }

        // If we need to insert at or beyond current length, push new element
        if (insertIndex >= currentLength) {
            // Append a new record to the array
            records.push(BalanceRecord(amount, expiresAt));
        } else if (records[insertIndex].amount == 0 && records[insertIndex].expiresAt == 0) {
            // Insert into empty slot
            records[insertIndex] = BalanceRecord(amount, expiresAt);
        } else {
            // Append a new empty record to the array
            records.push(BalanceRecord(0, 0));

            // Shift elements right from the last position
            for (uint256 i = records.length - 1; i > insertIndex; i--) {
                records[i] = records[i - 1];
            }

            // Insert the new record
            records[insertIndex] = BalanceRecord(amount, expiresAt);
        }
    }

    /**
     * @dev Deducts the specified `amount` from the balance records of the `account` for the given `id`.
     * Uses FIFO order (oldest expiration first).
     *
     * Reverts if the account does not have enough balance to cover the `amount`.
     *
     * @param account The address of the account to deduct from.
     * @param id The identifier of the token type to deduct from.
     * @param amount The amount to deduct from the balance records.
     */
    function _deductFromBalanceRecords(address account, uint256 id, uint256 amount) internal {
        BalanceRecord[] storage records = _balanceRecords[account][id];
        uint256 debt = amount;
        uint256 currentTime = block.timestamp;
        uint256 currentLength = records.length;

        for (uint256 i = 0; i < currentLength && debt > 0; i++) {
            // Skip expired or empty records
            if (records[i].expiresAt <= currentTime || records[i].amount == 0) {
                continue;
            }

            if (records[i].amount > debt) {
                // Partial burn
                records[i].amount -= uint256(debt);
                debt = 0;
            } else {
                // Full burn
                debt -= records[i].amount;
                records[i].amount = 0;
            }
        }

        if (debt > 0) {
            revert TokenTTLInsufficientBalance(account, amount - debt, amount, id);
        }

        // Prune expired records from the `account`
        _pruneBalanceRecords(account, id);
    }

    /**
     * @dev Transfer tokens from one account to another, preserving expiration times.
     * Uses FIFO order (oldest expiration first).
     *
     * If `from` and `to` are the same, or `amount` is 0, it does nothing.
     *
     * Reverts if the `from` account does not have enough balance to cover the `amount`.
     *
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param id The identifier of the token type to transfer.
     * @param amount The number of tokens to transfer.
     */
    function _transferBalanceRecords(address from, address to, uint256 id, uint256 amount) internal {
        if (from == to || amount == 0) return;

        BalanceRecord[] storage fromRecords = _balanceRecords[from][id];
        uint256 debt = amount;
        uint256 currentTime = block.timestamp;
        uint256 currentLength = fromRecords.length;

        for (uint256 i = 0; i < currentLength && debt > 0; i++) {
            // Skip expired or empty records
            if (fromRecords[i].expiresAt <= currentTime || fromRecords[i].amount == 0) {
                continue;
            }

            if (fromRecords[i].amount > debt) {
                // Transfer partial record
                _addToBalanceRecord(to, id, uint256(debt), fromRecords[i].expiresAt);
                fromRecords[i].amount -= uint256(debt);
                debt = 0;
            } else {
                // Transfer entire record
                _addToBalanceRecord(to, id, fromRecords[i].amount, fromRecords[i].expiresAt);
                debt -= fromRecords[i].amount;
                fromRecords[i].amount = 0;
            }
        }

        if (debt > 0) {
            revert TokenTTLInsufficientBalance(from, amount - debt, amount, id);
        }

        // Prune expired records from the `from` account
        _pruneBalanceRecords(from, id);
    }

    /**
     * @dev Remove expired or empty balance records and compact the array.
     *
     * @param account The address of the account to prune.
     * @param id The identifier of the token type to prune.
     */
    function _pruneBalanceRecords(address account, uint256 id) internal {
        BalanceRecord[] storage records = _balanceRecords[account][id];
        uint256 currentTime = block.timestamp;
        uint256 writeIndex = 0;
        uint256 currentLength = records.length;

        // Compact valid records to the front
        for (uint256 i = 0; i < currentLength; i++) {
            bool isValid = records[i].amount > 0 && records[i].expiresAt > currentTime;
            if (isValid) {
                if (i != writeIndex) {
                    records[writeIndex] = records[i];
                }
                writeIndex++;
            }
        }

        // Clear remaining slots
        for (uint256 i = writeIndex; i < currentLength; i++) {
            records[i] = BalanceRecord(0, 0);
        }

        // Optionally shrink the array if many slots are empty
        // This helps keep storage costs down
        if (writeIndex == 0 && currentLength > 0) {
            // All records are invalid, clear the array
            while (records.length > 0) {
                records.pop();
            }
        } else if (currentLength > writeIndex * 2 && currentLength > 10) {
            // If less than half the array is used and array is large, shrink it
            while (records.length > writeIndex) {
                records.pop();
            }
        }
    }

    /**
     * @dev Sets the TTL (time-to-live) for a token `id` (in seconds).
     * This function can only be called once per token `id`. If the token configuration
     * already exists, it reverts with an error.
     *
     * Emits a {EVMAuth6909TTLUpdated} event.
     *
     * Revert if the token configuration does not exist.
     *
     * @param id The identifier of the token type to set the TTL for.
     * @param ttl The time-to-live in seconds for the token. If 0, the token does not expire.
     */
    function _setTTL(uint256 id, uint256 ttl) internal {
        if (_ttlConfigs[id].isSet) {
            revert TokenTTLAlreadySet(id, ttl);
        }

        _ttlConfigs[id] = TTLConfig(true, ttl);

        emit TTLUpdated(_msgSender(), id, ttl);
    }

    /**
     * @dev Calculates the expiration time for a token `id` based on its TTL.
     * If the TTL is 0, the token does not expire and returns the maximum value for `uint256`.
     * Otherwise, it calculates the expiration time rounded up to the next bucket size.
     *
     * To avoid unbounded storage growth, we limit the number of balance records per address, per token `id`.
     * We lose some precision in the expiration time, but this helps ensure we can store balance records and
     * clean up expired records without running out of gas or hitting storage limits.
     *
     * We round UP to the next expiry bucket to guarantee AT LEAST the full `ttl` of the token. For example, if
     * `ttl` is 30 days and `MAX_BALANCE_RECORDS` is 30, the bucket size is 1 day, and the expiration will be
     * rounded up to the next day, giving the recipient at most an additional 23:59:59 to use the token.
     *
     * Revert if the token configuration does not exist.
     *
     * @param id The identifier of the token type to get the expiration time for.
     * @return The expiration timestamp for the token `id`.
     */
    function _expiration(uint256 id) internal view returns (uint256) {
        if (!_ttlConfigs[id].isSet) {
            revert TokenTLLNotSet(id);
        }

        uint256 ttl = _ttlConfigs[id].ttl;

        if (ttl == 0) {
            return type(uint256).max;
        }

        uint256 exactExpiration = block.timestamp + ttl;
        uint256 arraySize = _maxBalanceRecords();
        uint256 bucketSize = ttl / arraySize;
        if (bucketSize == 0) {
            bucketSize = 1;
        }

        return ((exactExpiration + bucketSize - 1) / bucketSize) * bucketSize;
    }
}
