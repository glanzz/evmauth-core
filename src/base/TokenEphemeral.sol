// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @title TokenEphemeral
 * @author EVMAuth
 * @notice Implements time-based token expiration with automatic balance pruning.
 * @dev Abstract contract providing TTL functionality for tokens with FIFO spending logic.
 * Expired tokens are automatically excluded from balances and pruned for gas optimization.
 * Uses EIP-7201 storage pattern for upgrade safety.
 */
abstract contract TokenEphemeral is ContextUpgradeable {
    /**
     * @notice Default limit for balance records per account per token.
     * @dev Can be overridden via _maxBalanceRecords() function.
     */
    uint256 public constant DEFAULT_MAX_BALANCE_RECORDS = 100;

    /**
     * @notice Balance record with amount and expiration timestamp.
     * @param amount Token balance that expires
     * @param expiresAt Unix timestamp of expiration (type(uint256).max for permanent)
     */
    struct BalanceRecord {
        uint256 amount; // Balance that expires at `expiresAt`
        uint256 expiresAt; // Set to max value to indicate no expiration
    }

    /// @custom:storage-location erc7201:tokenephemeral.storage.TokenEphemeral
    struct TokenEphemeralStorage {
        /**
         * @notice Nested mapping of account -> tokenId -> balance records array.
         * @dev Stores time-bucketed balance records for FIFO processing.
         */
        mapping(address account => mapping(uint256 id => BalanceRecord[])) balanceRecords;
        /**
         * @notice Token TTL configuration mapping.
         * @dev Maps tokenId to TTL in seconds (0 = permanent)
         */
        mapping(uint256 => uint256) ttls;
    }

    /**
     * @notice Emitted when pruned tokens are burned.
     * @param from Address from which tokens were pruned
     * @param id Token type identifier
     * @param amount Quantity of tokens that were pruned (expired)
     */
    event ExpiredTokensPruned(address indexed from, uint256 indexed id, uint256 amount);

    /**
     * @notice EIP-7201 storage slot for TokenEphemeral state.
     * @dev Computed as: keccak256(abi.encode(uint256(keccak256("tokenephemeral.storage.TokenEphemeral")) - 1))
     * & ~bytes32(uint256(0xff)). Prevents storage collisions in upgradeable contracts.
     */
    bytes32 private constant TokenEphemeralStorageLocation =
        0xec3c1253ecdf88a29ff53024f0721fc3faa1b42abcff612deb5b22d1f94e2d00;

    /**
     * @notice Retrieves the storage struct for TokenEphemeral.
     * @dev Internal function using inline assembly for direct storage access.
     * @return $ Storage pointer to TokenEphemeralStorage struct
     */
    function _getTokenEphemeralStorage() private pure returns (TokenEphemeralStorage storage $) {
        assembly {
            $.slot := TokenEphemeralStorageLocation
        }
    }

    /**
     * @notice Error for insufficient token balance.
     * @param account Address with insufficient balance.
     * @param available Current available balance
     * @param requested Amount requested
     * @param id Token type identifier
     */
    error InsufficientBalance(address account, uint256 available, uint256 requested, uint256 id);

    /**
     * @notice Internal initializer for TokenEphemeral setup.
     * @dev Currently empty as no initialization needed.
     */
    function __TokenEphemeral_init() internal onlyInitializing { }

    /**
     * @notice Unchained initializer for contract-specific storage.
     * @dev Currently empty but reserved for future initialization.
     */
    function __TokenEphemeral_init_unchained() internal onlyInitializing { }

    /**
     * @notice Gets current balance excluding expired tokens.
     * @dev Iterates through balance records and sums non-expired amounts.
     * @param account Address to check balance for
     * @param id Token type identifier
     * @return Total non-expired balance
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
     * @notice Retrieves all balance records for an account and token.
     * @dev Returns raw records including expired ones.
     * @param account Address to query
     * @param id Token type identifier
     * @return Array of balance records for the account/token pair
     */
    function balanceRecordsOf(address account, uint256 id) external view returns (BalanceRecord[] memory) {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        return $.balanceRecords[account][id];
    }

    /**
     * @notice Gets time-to-live configuration for a token type.
     * @dev Returns TTL in seconds, 0 indicates permanent tokens.
     * @param id Token type identifier
     * @return TTL in seconds (0 = no expiration)
     */
    function tokenTTL(uint256 id) public view virtual returns (uint256) {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        return $.ttls[id];
    }

    /**
     * @notice Removes expired and zero-balance records for gas optimization.
     * @dev Public function for manual storage cleanup. Automatically called during transfers.
     * @param account Address to prune records for
     * @param id Token type identifier
     * @custom:emits ExpiredTokensPruned if any tokens were pruned.
     */
    function pruneBalanceRecords(address account, uint256 id) public virtual {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        BalanceRecord[] storage records = $.balanceRecords[account][id];
        uint256 currentTime = block.timestamp;
        uint256 writeIndex = 0;
        uint256 currentLength = records.length;
        uint256 expiredAmount = 0; // This amount must be burned using the token standard's burn method

        // Compact valid records to the front
        for (uint256 i = 0; i < currentLength; i++) {
            if (records[i].amount == 0) {
                continue; // Skip empty records
            }

            if (records[i].expiresAt > currentTime) {
                // Record is still valid; move it to the write index if needed
                if (i != writeIndex) {
                    records[writeIndex] = records[i];
                }
                writeIndex++;
            } else {
                // Record is expired; accumulate expired amount
                expiredAmount += records[i].amount;
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

        // If any tokens were pruned (expired), call the _burnPrunedTokens hook and emit event
        if (expiredAmount > 0) {
            _burnPrunedTokens(account, id, expiredAmount);
            emit ExpiredTokensPruned(account, id, expiredAmount);
        }
    }

    /**
     * @notice Internal hook to handle burning of pruned tokens.
     * @dev Override this function to integrate with the token standard's burn mechanism.
     * Called automatically during pruning if expired tokens are found.
     * @param account Address from which tokens were pruned
     * @param id Token type identifier
     * @param amount Quantity of tokens that were pruned (expired)
     */
    function _burnPrunedTokens(address account, uint256 id, uint256 amount) internal virtual;

    /**
     * @notice Internal function to configure token TTL.
     * @dev Sets expiration duration for new tokens of this type.
     * @param id Token type identifier
     * @param ttlSeconds Duration in seconds (0 = permanent)
     */
    function _setTTL(uint256 id, uint256 ttlSeconds) internal virtual {
        TokenEphemeralStorage storage $ = _getTokenEphemeralStorage();
        $.ttls[id] = ttlSeconds;
    }

    /**
     * @notice Calculates bucketed expiration timestamp for a token.
     * @dev Rounds up to next time bucket to ensure minimum TTL guarantee.
     * Bucketing prevents unbounded storage growth by limiting unique expiration times.
     * Example: 30-day TTL with 100 max records creates 100 buckets of 25920 seconds (7.2 hours) each.
     * @param id Token type identifier
     * @return Unix timestamp of expiration (type(uint256).max for permanent)
     */
    function _expiresAt(uint256 id) internal view returns (uint256) {
        uint256 _ttl = tokenTTL(id);

        if (_ttl == 0) {
            return type(uint256).max;
        }

        uint256 exactExpiration = block.timestamp + _ttl;
        uint256 bucketSize = _ttl / _maxBalanceRecords();

        if (bucketSize == 0) {
            bucketSize = 1;
        }

        // Ceiling division: round up to the next bucket boundary
        // This ensures tokens last AT LEAST the TTL duration
        uint256 buckets = (exactExpiration + bucketSize - 1) / bucketSize;
        return buckets * bucketSize;
    }

    /**
     * @notice Returns maximum balance records per account/token pair.
     * @dev Limits storage to prevent DoS attacks. Override to customize.
     * Affects expiration precision: actual expiry is anywhere from TTL to TTL + (TTL/maxRecords - 1) seconds.
     * @return Maximum number of balance records (default: 100)
     */
    function _maxBalanceRecords() internal view virtual returns (uint256) {
        return DEFAULT_MAX_BALANCE_RECORDS;
    }

    /**
     * @notice Internal hook to update balance records on token transfers.
     * @dev Handles minting, burning, and transfers with automatic pruning.
     * Automatically prunes expired records before adding and/or after deducting balances.
     * @param from Source address (zero address for minting)
     * @param to Destination address (zero address for burning)
     * @param id Token type identifier
     * @param amount Quantity transferred
     */
    function _updateBalanceRecords(address from, address to, uint256 id, uint256 amount) internal virtual {
        // Update balance records in the TokenEphemeral contract
        if (from == address(0)) {
            // Minting
            pruneBalanceRecords(to, id);
            _addToBalanceRecords(to, id, amount, _expiresAt(id));
        } else if (to == address(0)) {
            // Burning
            _deductFromBalanceRecords(from, id, amount);
            pruneBalanceRecords(from, id);
        } else {
            // Transfer
            pruneBalanceRecords(to, id);
            _transferBalanceRecords(from, to, id, amount);
            pruneBalanceRecords(from, id);
        }
    }

    /**
     * @notice Internal function to add or update balance records.
     * @dev Maintains chronological sorting and merges same-expiration records.
     * In most cases, _updateBalanceRecords() should be called instead of calling this directly.
     * @param account Address to update balance for
     * @param id Token type identifier
     * @param amount Quantity to add
     * @param expiresAt Unix timestamp of expiration
     */
    function _addToBalanceRecords(address account, uint256 id, uint256 amount, uint256 expiresAt) internal {
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
     * @notice Internal function to deduct tokens using FIFO logic.
     * @dev Consumes oldest tokens first, automatically prunes after deduction.
     * In most cases, _updateBalanceRecords() should be called instead of calling this directly.
     * @param account Address to deduct from
     * @param id Token type identifier
     * @param amount Quantity to deduct
     * @custom:throws InsufficientBalance When account lacks sufficient non-expired balance
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
    }

    /**
     * @notice Internal function to transfer tokens preserving expiration.
     * @dev Uses FIFO to transfer oldest tokens first, maintains expiration timestamps.
     * In most cases, _updateBalanceRecords() should be called instead of calling this directly.
     * @param from Source address
     * @param to Destination address
     * @param id Token type identifier
     * @param amount Quantity to transfer
     * @custom:throws InsufficientBalance When sender lacks sufficient non-expired balance
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
                _addToBalanceRecords(to, id, uint256(debt), fromRecords[i].expiresAt);
                fromRecords[i].amount -= uint256(debt);
                debt = 0;
            } else {
                // Transfer entire record
                _addToBalanceRecords(to, id, fromRecords[i].amount, fromRecords[i].expiresAt);
                debt -= fromRecords[i].amount;
                fromRecords[i].amount = 0;
            }
        }

        if (debt > 0) {
            revert InsufficientBalance(from, amount - debt, amount, id);
        }
    }
}
