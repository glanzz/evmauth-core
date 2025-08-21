// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155AccessControl} from "./IERC1155AccessControl.sol";
import {IERC1155Price} from "./extensions/IERC1155Price.sol";

/**
 * @dev Interface for ERC1155AccessControl with price management functionality.
 */
interface IERC1155AccessControlPrice is IERC1155AccessControl, IERC1155Price {
    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Emits a {ERC1155PriceUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setPrice(uint256 id, uint256 price) external;

    /**
     * @dev Suspends the price for a specific token `id`, preventing purchases.
     *
     * Emits a {ERC1155PriceSuspended} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function suspendPrice(uint256 id) external;

    /**
     * @dev Sets the treasury address that will receive token purchase revenues.
     *
     * Emits a {TreasuryUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TREASURER_ROLE`.
     */
    function setTreasury(address payable treasuryAccount) external;
}
