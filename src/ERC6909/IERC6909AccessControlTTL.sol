// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909TTL} from "./extensions/IERC6909TTL.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with extended features and access controls.
 */
interface IERC6909AccessControlTTL is IERC6909TTL {
    /**
     * @dev Sets the TTL for a specific token `id`.
     *
     * Emits a {ERC6909TTLUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTTL(uint256 id, uint256 ttl) external;
}
