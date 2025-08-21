// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909Price} from "./extensions/IERC6909Price.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with extended features and access controls.
 */
interface IERC6909AccessControlPrice is IERC6909Price {
    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Emits a {ERC6909PriceUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setPrice(uint256 id, uint256 price) external;

    /**
     * @dev Suspends the price for a specific token `id`, preventing purchases.
     *
     * Emits a {ERC6909PriceSuspended} event.
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
