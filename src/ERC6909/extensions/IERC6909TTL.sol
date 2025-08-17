// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with expiring tokens.
 */
interface IERC6909TTL is IERC6909 {
    /**
     * @dev Emitted when the token configuration for a token `id` is set by `caller`.
     */
    event TokenTTLSet(address caller, uint256 indexed id, uint256 ttl);

    /**
     * @dev Returns true if the TTL for a specific token `id` has been set.
     * Once a TTL is set for a token `id`, it cannot be changed or removed. This is necessary because expiring
     * tokens are grouped into expiration time buckets, to prevent denial-of-service attacks based on unbounded
     * data storage.
     *
     * If the TTL is set to 0, it will still return true, as it indicates that the TTL was intentionally set to 0.
     */
    function ttlIsSet(uint256 id) external view returns (bool);

    /**
     * @dev Returns the TTL (time-to-live) of a token `id` (in seconds).
     * If the TTL is set to 0, it means the token does not expire.
     *
     * Reverts if the token TTL has not yet been set.
     */
    function ttlOf(uint256 id) external view returns (uint256);
}
