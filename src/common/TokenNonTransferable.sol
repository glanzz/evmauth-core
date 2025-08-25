// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/ContextUpgradeable.sol";

/**
 * @dev Mixin to add non-transferable functionality to token contracts.
 */
abstract contract TokenNonTransferable is ContextUpgradeable {
    /**
     * @dev Mapping from token `id` to its non-transferable status.
     * If `true`, the token cannot be transferred between accounts.
     */
    mapping(uint256 => bool) private _nonTransferableTokens;

    /**
     * @dev Emitted when the non-transferable status of a token `id` is updated.
     */
    event TokenNonTransferableUpdated(address caller, uint256 indexed id, bool nonTransferable);

    /**
     * @dev Error thrown when a transfer is attempted for a non-transferable token `id`.
     */
    error TokenIsNonTransferable(uint256 id);

    /**
     * @dev Modifier to check if a token `id` can be transferred between accounts,
     * while also ensuring that neither the sender nor the receiver is the zero address.
     *
     * Reverts with {TokenNonTransferable} error if the token is non-transferable.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param id The identifier of the token type to check.
     * @notice This modifier should be applied to a core function that handle single token transfers,
     * like the `_update` method in OpenZeppelin's {ERC6909} contract.
     */
    modifier denyTransferIfNonTransferable(address from, address to, uint256 id) {
        if (from != address(0) && to != address(0) && _nonTransferableTokens[id]) {
            revert TokenIsNonTransferable(id);
        }
        _;
    }

    /**
     * @dev Modifier to check if a batch of token `ids` can be transferred between accounts,
     * while also ensuring that neither the sender nor the receiver is the zero address.
     * Reverts with {TokenNonTransferable} error if any token in the batch is non-transferable.
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param ids The identifiers of the token types to check.
     * @notice This modifier should be applied to a core function that handle batch token transfers,
     * like the `_update` method in OpenZeppelin's {ERC1155} contract.
     */
    modifier denyBatchTransferIfAnyNonTransferable(address from, address to, uint256[] memory ids) {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (_nonTransferableTokens[ids[i]]) {
                    revert TokenIsNonTransferable(ids[i]);
                }
            }
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenNonTransferable_init() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenNonTransferable_init_unchained() public onlyInitializing {
        // Nothing to initialize
    }

    /**
     * @dev Check if a token `id` can be transferred between accounts.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the token `id` is transferable.
     */
    function isTransferable(uint256 id) public view virtual returns (bool) {
        return !_nonTransferableTokens[id];
    }

    /**
     * @dev Sets the non-transferable status of a specific token `id`.
     *
     * Emits a {ERC6909NonTransferableUpdated} event.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function _setNonTransferable(uint256 id, bool nonTransferable) internal virtual {
        _nonTransferableTokens[id] = nonTransferable;
        emit TokenNonTransferableUpdated(_msgSender(), id, nonTransferable);
    }
}
