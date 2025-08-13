// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with support for expiring tokens.
 */
interface IERC6909Purchasable is IERC6909 {
    /**
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Emitted when the price of a token `id` is set by `caller`.
     */
    event TokenPriceSet(address caller, uint256 indexed id, uint256 price);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasurySet(address caller, address indexed account);

    /**
     * @dev Returns the price of a specific token `id`.
     */
    function priceOf(uint256 id) external view returns (uint256);

    /**
     * @dev Returns the treasury address where purchase revenues are sent.
     * This address must be set before any purchases can be made.
     * If not set, it will revert when trying to purchase tokens.
     *
     * If you want to keep the treasury address private or implement custom logic,
     * you can override this function and the `_setTreasury` function.
     */
    function treasury() external returns (address);

    /**
     * @dev Purchases `amount` tokens of type `id` for the caller.
     * The payment is made in the native currency, and the tokens are minted to the caller's address.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the caller's address.
     * Emits a {Purchase} event where the `caller` is the same as the `receiver`.
     */
    function purchase(uint256 id, uint256 amount) external payable returns (bool);

    /**
     * @dev Purchases `amount` tokens of type `id` for a specific `receiver`.
     * The payment is made in the native currency, and the tokens are minted to the `receiver`'s address.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     */
    function purchaseFor(address receiver, uint256 id, uint256 amount) external payable returns (bool);
}
