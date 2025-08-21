// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155AccessControl} from "./IERC1155AccessControl.sol";
import {IERC1155TTL} from "./extensions/IERC1155TTL.sol";

/**
 * @dev Interface for ERC1155AccessControl with time-to-live (TTL) functionality.
 */
interface IERC1155AccessControlTTL is IERC1155AccessControl, IERC1155TTL {
    /**
     * @dev Sets the TTL for a specific token `id`.
     *
     * Emits a {ERC1155TTLUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTTL(uint256 id, uint256 ttl) external;
}
