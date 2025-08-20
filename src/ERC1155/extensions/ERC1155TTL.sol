// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155TTL} from "./IERC1155TTL.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with expiring tokens.
 */
abstract contract ERC1155TTL is ERC1155, IERC1155TTL {
    // Maximum per address, per token ID
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

    // Errors
    error ERC1155TTLTokenTTLAlreadySet(uint256 id, uint256 ttl);
    error ERC1155TTLTokenTLLNotSet(uint256 id);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IERC1155TTL).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155TTL
    function ttlIsSet(uint256 id) external view returns (bool) {
        return _ttlConfigs[id].isSet;
    }

    /// @inheritdoc IERC1155TTL
    function ttlOf(uint256 id) external view returns (uint256) {
        if (!_ttlConfigs[id].isSet) {
            // We need to revert here, to prevent un-configured tokens from being treated as non-expiring
            revert ERC1155TTLTokenTLLNotSet(id);
        }

        return _ttlConfigs[id].ttl;
    }

    /// @inheritdoc IERC1155
    function balanceOf(address owner, uint256 id) public view virtual override(ERC1155, IERC1155) returns (uint256) {
        BalanceRecord[] storage records = _balanceRecords[owner][id];
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
     * @dev Transfers `values` amounts of tokens of types `ids` from `from` to `to`, or alternatively mints (or burns)
     * if `from` (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by
     * overriding this function.
     *
     * Emits either {TransferSingle} or {TransferBatch} events, depending on the lengths of the arrays.
     *
     * Requirements:
     * - if `from` is the zero address, `to` must not be the zero address (minting).
     * - if `to` is the zero address, `from` must not be the zero address (burning).
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover all `values`.
     * - if `from` and `to` are the same, it does nothing.
     * - if a value in `values` is zero, it skips that token type.
     * - `ids` and `values` must have the same length.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param ids The identifiers of the token types to transfer.
     * @param values The numbers of tokens to transfer.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        if (from == to) {
            return;
        }

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 value = values[i];

            if (value == 0) {
                continue;
            }

            if (from == address(0)) {
                // Mint
                if (to == address(0)) {
                    revert ERC1155InvalidReceiver(address(0));
                }
                uint256 expiresAt = _expiration(id);
                _addToBalanceRecord(to, id, value, expiresAt);
            } else if (to == address(0)) {
                // Burn
                uint256 fromBalance = balanceOf(from, id);
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                _deductFromBalanceRecords(from, id, value);
            } else {
                // Transfer
                uint256 fromBalance = balanceOf(from, id);
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                _transferBalanceRecords(from, to, id, value);
            }
        }

        // Call the parent update function, which may be ERC1155, an ERC1155 extension, or another override
        super._update(from, to, ids, values);
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
                records[i].amount -= debt;
                debt = 0;
            } else {
                // Full burn
                debt -= records[i].amount;
                records[i].amount = 0;
            }
        }

        if (debt > 0) {
            revert ERC1155InsufficientBalance(account, amount - debt, amount, id);
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
                _addToBalanceRecord(to, id, debt, fromRecords[i].expiresAt);
                fromRecords[i].amount -= debt;
                debt = 0;
            } else {
                // Transfer entire record
                _addToBalanceRecord(to, id, fromRecords[i].amount, fromRecords[i].expiresAt);
                debt -= fromRecords[i].amount;
                fromRecords[i].amount = 0;
            }
        }

        if (debt > 0) {
            revert ERC1155InsufficientBalance(from, amount - debt, amount, id);
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
     * Emits a {ERC1155TTLUpdated} event.
     *
     * Revert if the token configuration does not exist.
     *
     * @param id The identifier of the token type to set the TTL for.
     * @param ttl The time-to-live in seconds for the token. If 0, the token does not expire.
     */
    function _setTokenTTL(uint256 id, uint256 ttl) internal {
        if (_ttlConfigs[id].isSet) {
            revert ERC1155TTLTokenTTLAlreadySet(id, ttl);
        }

        _ttlConfigs[id] = TTLConfig(true, ttl);

        emit ERC1155TTLUpdated(_msgSender(), id, ttl);
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
            revert ERC1155TTLTokenTLLNotSet(id);
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

    /**
     * @dev Returns the length of the balance records array for a given account and token ID.
     * This is an internal helper function primarily used for testing purposes.
     *
     * @param account The address of the account.
     * @param id The identifier of the token type.
     * @return The length of the balance records array.
     */
    function _getBalanceRecordsLength(address account, uint256 id) internal view returns (uint256) {
        return _balanceRecords[account][id].length;
    }
}
