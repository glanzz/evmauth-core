// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface of an ERC-6909 compliant contract with extended features and access controls.
 */
interface IERC6909AccessControl {
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
     * @dev Sets the `contractURI` for the contract.
     *
     * Emits a {ContractURIUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Sets the `tokenURI` for a specific token `id`.
     *
     * Emits a {URI} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenURI(uint256 id, string memory tokenURI) external;

    /**
     * @dev Sets the name for a given token of type `id`.
     *
     * Emits a {ERC6909NameUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenName(uint256 id, string memory name) external;

    /**
     * @dev Sets the symbol for a given token of type `id`.
     *
     * Emits a {ERC6909SymbolUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenSymbol(uint256 id, string memory symbol) external;

    /**
     * @dev Sets the decimals for a given token of type `id`.
     *
     * Emits a {ERC6909DecimalsUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenDecimals(uint256 id, uint8 decimals) external;

    /**
     * @dev Sets the non-transferable status of a specific token `id`.
     *
     * Emits a {ERC6909NonTransferableUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setNonTransferable(uint256 id, bool nonTransferable) external;

    /**
     * @dev Mints `amount` of token type `id` to `to`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - The caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev Burns `amount` of token type `id` from `from`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - The caller must have the `BURNER_ROLE`.
     */
    function burn(address from, uint256 id, uint256 amount) external returns (bool);
}
