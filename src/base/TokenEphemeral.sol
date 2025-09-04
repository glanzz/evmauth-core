// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Abstract contract that provides configurable time-to-live (TTL) and expiring token balances with
 * first-in-first-out (FIFO) spending and transfer logic.
 */
abstract contract TokenEphemeral is ContextUpgradeable {
    /**
     * @dev Default maximum number of balance records per address, per token ID.
     *
     * This can be overridden by inheriting contracts that override the `_maxBalanceRecords` function.
     */
    uint256 public constant DEFAULT_MAX_BALANCE_RECORDS = 30;

    /**
     * @dev A record of a balance amount and its expiration time.
     */
    struct BalanceRecord {
        uint256 amount; // Balance that expires at `expiresAt`
        uint256 expiresAt; // Set to max value to indicate no expiration
    }

    /// @custom:storage-location erc7201:tokenephemeral.storage.TokenEphemeral
    struct TokenEphemeralStorage {
        /**
         * @dev Mapping from `account` to token `id`, to an array of balance records for that token.
         */
        mapping(address account => mapping(uint256 id => BalanceRecord[])) balanceRecords;
        /**
         * @dev Mapping from token `id` to its time-to-live (TTL) in seconds. A TTL of 0 means the token never expires.
         */
        mapping(uint256 => uint256) ttls;
    }

    /**
     * @dev Storage location for the `TokenEphemeral` contract, as defined by EIP-7201.
     *
     * This is a keccak-256 hash of a unique string, minus 1, and then rounded down to the nearest
     * multiple of 256 bits (32 bytes) to avoid potential storage slot collisions with other
     * upgradeable contracts that may be added to the same deployment.
     *
     * keccak256(abi.encode(uint256(keccak256("tokenephemeral.storage.TokenEphemeral")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 private constant TokenEphemeralStorageLocation =
        0xec3c1253ecdf88a29ff53024f0721fc3faa1b42abcff612deb5b22d1f94e2d00;

    /**
     * @dev Returns the storage struct for the `TokenEphemeral` contract.
     */
    function _getTokenEphemeralStorage() private pure returns (TokenEphemeralStorage storage $) {
        assembly {
            $.slot := TokenEphemeralStorageLocation
        }
    }

    /**
     * @dev Error thrown when deducting or transferring tokens from an account with insufficient funds.
     */
    error InsufficientBalance(address account, uint256 available, uint256 requested, uint256 id);

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenEphemeral_init() internal onlyInitializing { }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenEphemeral_init_unchained() internal onlyInitializing { }

    /**
     * @dev Returns the balance of a given token `id` for a given `account`, excluding expired tokens.
     *
     * @param account The address of the account to check the balance for.
     * @param id The identifier of the token type to check the balance for.
     * @return The balance of the token `id` for the specified `account`, excluding expired tokens.
     */
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage records = $.balanceRecords[account][id];
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
     * @dev Returns the balance records array for a given `account` and token `id`.
     *
     * @param account The address of the account.
     * @param id The identifier of the token type.
     * @return The array of balance records.
     */
    function balanceRecordsOf(address account, uint256 id) external view returns (BalanceRecord[] memory) {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        return $.balanceRecords[account][id];
    }

    /**
     * @dev Returns the time-to-live (TTL) in seconds for a given token `id`.
     * A TTL of 0 means the token never expires.
     *
     * @param id The identifier of the token type to get the TTL for.
     * @return The TTL in seconds for the given token `id`.
     */
    function tokenTTL(uint256 id) public view virtual returns (uint256) {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        return $.ttls[id];
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
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage records = $.balanceRecords[account][id];
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
     * @dev Sets the time-to-live (TTL) in seconds for a given token `id`.
     * A TTL of 0 means the token never expires.
     *
     * @param id The identifier of the token type to set the TTL for.
     * @param ttlSeconds The TTL in seconds for the given token `id`.
     */
    function _setTTL(uint256 id, uint256 ttlSeconds) internal virtual {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        $.ttls[id] = ttlSeconds;
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
    function _expiresAt(uint256 id) internal view returns (uint256) {
        uint256 _ttl = tokenTTL(id);

        if (_ttl == 0) {
            return type(uint256).max;
        }

        uint256 exactExpiration = block.timestamp + _ttl;
        uint256 arraySize = _maxBalanceRecords();
        uint256 bucketSize = _ttl / arraySize;

        if (bucketSize == 0) {
            bucketSize = 1;
        }

        return ((exactExpiration + bucketSize - 1) / bucketSize) * bucketSize;
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

        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage records = $.balanceRecords[account][id];
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
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage records = $.balanceRecords[account][id];
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

        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage fromRecords = $.balanceRecords[from][id];
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
}
