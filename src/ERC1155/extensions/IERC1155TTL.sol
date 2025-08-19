// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract with expiring tokens.
 */
interface IERC1155TTL is IERC1155 {
    /**
     * @dev Emitted when the TTL for a token `id` is set by `caller`.
     */
    event ERC1155TTLUpdated(address caller, uint256 indexed id, uint256 ttl);

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