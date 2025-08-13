// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with expiring tokens.
 */
interface IERC6909Expiring is IERC6909 {
    /**
     * @dev Emitted when the token configuration for a token `id` is set by `caller`.
     */
    event TokenTTLSet(address caller, uint256 indexed id, uint256 ttl);

    /**
     * @dev Returns true if TTL has been set for token `id`.
     */
    function ttlIsSet(uint256 id) external view returns (bool);

    /**
     * @dev Returns the TTL (time-to-live) of a token `id` (in seconds).
     *
     * Reverts if the token TTL has not yet been set.
     */
    function ttlOf(uint256 id) external view returns (uint256);
}
