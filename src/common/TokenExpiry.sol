// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenConfiguration } from "src/common/TokenConfiguration.sol";

/**
 * @dev Mixin that provides automatic expiration functionality for token contracts.
 * Tokens can be configured to expire after a certain period, and the contract manages balance
 * records with expiration times automatically.
 *
 * With sequential token IDs, we can determine if a TTL has been set by checking if the token exists.
 * A TTL of 0 means the token never expires.
 */
abstract contract TokenExpiry is TokenConfiguration {
    // Maximum BalanceRecord array size per address, per token ID
    uint256 public constant DEFAULT_MAX_BALANCE_RECORDS = 30;

    // Balance record data structure that ties an amount to an expiration time
    struct BalanceRecord {
        uint256 amount; // Balance that expires at `expiresAt`
        uint256 expiresAt; // Set to max value to indicate no expiration
    }

    // Owner => Token ID => Array of balance records
    mapping(address owner => mapping(uint256 id => BalanceRecord[])) private _balanceRecords;

    /**
     * @dev Error thrown when deducting or transferring tokens from an account with insufficient funds.
     */
    error InsufficientBalance(address account, uint256 available, uint256 requested, uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenExpiry_init() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenExpiry_init_unchained() public onlyInitializing {
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
        pruneBalanceRecords(account, id);

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
            revert InsufficientBalance(account, amount - debt, amount, id);
        }

        // Prune expired records from the `account`
        pruneBalanceRecords(account, id);
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
            revert InsufficientBalance(from, amount - debt, amount, id);
        }

        // Prune expired records from the `from` account
        pruneBalanceRecords(from, id);
    }

    /**
     * @dev Prunes balance records for a specific account, removing entries that are expired or
     * have a zero balances. This is handled automatically during transfers and minting, but can
     * be manually invoked to clean up storage.
     *
     * @param account The address of the account to prune.
     * @param id The identifier of the token type to prune.
     */
    function pruneBalanceRecords(address account, uint256 id) public virtual {
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
     * @param id The identifier of the token type to get the expiration time for.
     * @return The expiration timestamp for the token `id`.
     */
    function _expiration(uint256 id) internal view returns (uint256) {
        uint256 ttl = ttlOf(id);

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
