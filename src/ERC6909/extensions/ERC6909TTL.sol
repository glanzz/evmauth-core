// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909TTL} from "./IERC6909TTL.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with expiring tokens.
 */
abstract contract ERC6909TTL is ERC6909, IERC6909TTL {
    // Maximum per address, per token ID
    uint256 public constant MAX_BALANCE_RECORDS = 30;

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
    mapping(address owner => mapping(uint256 id => BalanceRecord[MAX_BALANCE_RECORDS])) private _balanceRecords;

    // Token ID => token configuration (cannot be changed after being set)
    mapping(uint256 id => TTLConfig) private _ttlConfigs;

    // Errors
    error ERC6909TTLTokenTTLAlreadySet(uint256 id, uint256 ttl);
    error ERC6909TTLTokenTLLNotSet(uint256 id);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, IERC165) returns (bool) {
        return interfaceId == type(IERC6909TTL).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909TTL
    function ttlIsSet(uint256 id) external view returns (bool) {
        return _ttlConfigs[id].isSet;
    }

    /// @inheritdoc IERC6909TTL
    function ttlOf(uint256 id) external view returns (uint256) {
        if (!_ttlConfigs[id].isSet) {
            // We need to revert here, to prevent un-configured tokens from being treated as non-expiring
            revert ERC6909TTLTokenTLLNotSet(id);
        }

        return _ttlConfigs[id].ttl;
    }

    /// @inheritdoc IERC6909
    function balanceOf(address owner, uint256 id) public view virtual override(ERC6909, IERC6909) returns (uint256) {
        BalanceRecord[MAX_BALANCE_RECORDS] storage records = _balanceRecords[owner][id];
        uint256 balance = 0;

        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].expiresAt > block.timestamp) {
                balance += records[i].amount;
            }
        }

        return balance;
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - if `from` is the zero address, `to` must not be the zero address (minting).
     * - if `to` is the zero address, `from` must not be the zero address (burning).
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `amount`.
     * - if `from` and `to` are the same, it does nothing.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param id The identifier of the token type to transfer.
     * @param amount The number of tokens to transfer.
     */
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override {
        if (from == address(0)) {
            // Mint
            if (to == address(0)) {
                revert ERC6909.ERC6909InvalidReceiver(address(0));
            }
            uint256 expiresAt = _expirationFor(id);
            _addToBalanceRecord(to, id, uint256(amount), expiresAt);
        } else if (to == address(0)) {
            // Burn
            uint256 fromBalance = balanceOf(from, id);
            if (fromBalance < amount) {
                revert ERC6909InsufficientBalance(from, fromBalance, amount, id);
            }
            _deductFromBalanceRecords(from, id, amount);
        } else {
            // Transfer
            uint256 fromBalance = balanceOf(from, id);
            if (fromBalance < amount) {
                revert ERC6909InsufficientBalance(from, fromBalance, amount, id);
            }
            _transferBalanceRecords(from, to, id, amount);
        }

        // Call the parent update function, which may be ERC6909, an ERC6909 extension, or another override
        super._update(from, to, id, amount);
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

        BalanceRecord[MAX_BALANCE_RECORDS] storage records = _balanceRecords[account][id];

        // Find the correct position to insert (sorted by expiration)
        uint256 insertIndex = MAX_BALANCE_RECORDS;
        for (uint256 i = 0; i < MAX_BALANCE_RECORDS; i++) {
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

        // If inserting in the middle, shift elements to the right
        if (records[insertIndex].amount != 0 || records[insertIndex].expiresAt != 0) {
            // Shift elements right from the last position
            // After pruning, all empty slots are at the end, so we can start from MAX_BALANCE_RECORDS - 1
            for (uint256 i = MAX_BALANCE_RECORDS - 1; i > insertIndex; i--) {
                records[i] = records[i - 1];
            }
        }

        // Insert the new record
        records[insertIndex] = BalanceRecord(amount, expiresAt);
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
        BalanceRecord[MAX_BALANCE_RECORDS] storage records = _balanceRecords[account][id];
        uint256 debt = amount;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < MAX_BALANCE_RECORDS && debt > 0; i++) {
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
            revert ERC6909InsufficientBalance(account, amount - debt, amount, id);
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

        BalanceRecord[MAX_BALANCE_RECORDS] storage fromRecords = _balanceRecords[from][id];
        uint256 debt = amount;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < MAX_BALANCE_RECORDS && debt > 0; i++) {
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
            revert ERC6909InsufficientBalance(from, amount - debt, amount, id);
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
        BalanceRecord[MAX_BALANCE_RECORDS] storage records = _balanceRecords[account][id];
        uint256 currentTime = block.timestamp;
        uint256 writeIndex = 0;

        // Compact valid records to the front
        for (uint256 i = 0; i < MAX_BALANCE_RECORDS; i++) {
            bool isValid = records[i].amount > 0 && records[i].expiresAt > currentTime;
            if (isValid) {
                if (i != writeIndex) {
                    records[writeIndex] = records[i];
                }
                writeIndex++;
            }
        }

        // Clear remaining slots
        for (uint256 i = writeIndex; i < MAX_BALANCE_RECORDS; i++) {
            records[i] = BalanceRecord(0, 0);
        }
    }

    /**
     * @dev Sets the TTL (time-to-live) for a token `id` (in seconds).
     * This function can only be called once per token `id`. If the token configuration
     * already exists, it reverts with an error.
     *
     * Emits a {ERC6909TTLUpdated} event.
     *
     * Revert if the token configuration does not exist.
     *
     * @param id The identifier of the token type to set the TTL for.
     * @param ttl The time-to-live in seconds for the token. If 0, the token does not expire.
     */
    function _setTokenTTL(uint256 id, uint256 ttl) internal {
        if (_ttlConfigs[id].isSet) {
            revert ERC6909TTLTokenTTLAlreadySet(id, ttl);
        }

        _ttlConfigs[id] = TTLConfig(true, ttl);

        emit ERC6909TTLUpdated(_msgSender(), id, ttl);
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
    function _expirationFor(uint256 id) internal view returns (uint256) {
        if (!_ttlConfigs[id].isSet) {
            revert ERC6909TTLTokenTLLNotSet(id);
        }

        uint256 ttl = _ttlConfigs[id].ttl;

        if (ttl == 0) {
            return type(uint256).max;
        }

        uint256 exactExpiration = block.timestamp + ttl;
        uint256 bucketSize = ttl / MAX_BALANCE_RECORDS;
        if (bucketSize == 0) {
            bucketSize = 1;
        }

        return ((exactExpiration + bucketSize - 1) / bucketSize) * bucketSize;
    }
}
