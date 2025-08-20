// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract that supports the direct purchase of tokens.
 */
interface IERC1155Price is IERC1155 {
    /**
     * @dev Emitted when `amount` tokens of type `id` are purchased by `caller` for `receiver`.
     */
    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);

    /**
     * @dev Emitted when the price of a token `id` is set by `caller`.
     */
    event ERC1155PriceUpdated(address caller, uint256 indexed id, uint256 price);

    /**
     * @dev Emitted when purchase of a token `id` is disabled by `caller`.
     */
    event ERC1155PriceSuspended(address caller, uint256 indexed id);

    /**
     * @dev Emitted when the treasury address is set by `caller`.
     */
    event TreasuryUpdated(address caller, address indexed account);

    /**
     * @dev Returns true if the price for a specific token `id` has been set.
     * This is useful to check if a token can be purchased.
     *
     * If the price is set to 0, it will still return true, as it indicates that the price was intentionally set to 0.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the price is set for the token `id`.
     */
    function isPriceSet(uint256 id) external view returns (bool);

    /**
     * @dev Returns the price of a specific token `id`.
     *
     * Revert if the price is not set for the token `id`.
     *
     * @param id The identifier of the token type to get the price for.
     * @return uint256 representing the price of the token `id`.
     */
    function priceOf(uint256 id) external view returns (uint256);

    /**
     * @dev Returns the treasury address where purchase revenues are sent.
     * This address must be set before any purchases can be made.
     * If not set, it will revert when trying to purchase tokens.
     *
     * @return address representing the treasury account.
     * @notice The treasury address is where the purchase revenues are sent. If you want to keep the treasury
     * address private or implement custom logic, you can override this function.
     */
    function treasury() external view returns (address);
}
