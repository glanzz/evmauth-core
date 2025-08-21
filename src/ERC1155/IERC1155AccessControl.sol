// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155Base} from "./extensions/IERC1155Base.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract with extended features and access controls.
 */
interface IERC1155AccessControl is IAccessControlDefaultAdminRules, IERC1155Base {
    /**
     * @dev Emitted when an address is frozen, unfrozen, added to, or removed from the allowlist.
     */
    event AccountStatusUpdate(address indexed account, bytes32 indexed status);

    /**
     * @dev Check if an `account` address is frozen.
     * A frozen account cannot purchase, transfer, or receive tokens.
     *
     * @param account The address of the account to check.
     * @return bool indicating whether the account is frozen.
     */
    function isFrozen(address account) external view returns (bool);

    /**
     * @dev Get the full list of frozen accounts.
     *
     * @return address[] An array of addresses that are frozen.
     */
    function frozenAccounts() external view returns (address[] memory);

    /**
     * @dev Freezes an `account`, preventing it from purchasing, transferring, or receiving tokens.
     * If the account is already frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_FROZEN_STATUS`.
     *
     * Requirements:
     * - The `account` cannot be the zero address.
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     *
     * @param account The address of the account to freeze.
     */
    function freezeAccount(address account) external;

    /**
     * @dev Unfreezes an `account`, allowing it to purchase, transfer, and receive tokens again.
     * If the account is not frozen, this function does nothing.
     *
     * Emits a {AccountStatusUpdate} event with `ACCOUNT_UNFROZEN_STATUS`.
     *
     * Requirements:
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     *
     * @param account The address of the account to unfreeze.
     */
    function unfreezeAccount(address account) external;

    /**
     * @dev Pauses the contract, preventing any token transfers or purchases.
     *
     * Emits a {Paused} event.
     *
     * Requirements:
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     */
    function pause() external;

    /**
     * @dev Unpauses the contract, allowing token transfers and purchases to resume.
     *
     * Emits a {Unpaused} event.
     *
     * Requirements:
     * - The caller must have the `ACCESS_MANAGER_ROLE`.
     */
    function unpause() external;

    /**
     * @dev Sets the base URI for all tokens.
     *
     * Emits a {URI} event for each token id.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setURI(string memory newuri) external;

    /**
     * @dev Sets the URI for a specific token `id`.
     *
     * Emits a {URI} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenURI(uint256 id, string memory tokenURI) external;

    /**
     * @dev Sets the non-transferable status of a specific token `id`.
     *
     * Emits a {ERC1155NonTransferableUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setNonTransferable(uint256 id, bool nonTransferable) external;

    /**
     * @dev Mints `amount` of token type `id` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev Mints `amounts` of token types `ids` to `to`.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     * - `ids` and `amounts` must have the same length.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external returns (bool);

    /**
     * @dev Burns `amount` of token type `id` from `from`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     * - The caller must have the `BURNER_ROLE`.
     */
    function burn(address from, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev Burns `amounts` of token types `ids` from `from`.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     * - The caller must have the `BURNER_ROLE`.
     * - `ids` and `amounts` must have the same length.
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external returns (bool);
}
