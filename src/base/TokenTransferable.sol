// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Provides sequential token ID tracking, transferability management, and a unified configuration interface
 * with hooks for extensibility.
 */
abstract contract TokenTransferable is ContextUpgradeable {
    /**
     * @dev Token transferability mapping.
     * true = transferable, false = non-transferable
     */
    mapping(uint256 => bool) private _transferable;

    /**
     * @dev Error thrown when a transfer is attempted for a non-transferable token `id`.
     */
    error TokenIsNonTransferable(uint256 id);

    /**
     * @dev Modifier to require that a token `id` can be transferred between accounts. If either `from` or `to`
     * is the zero address, the transferability check is skipped (to allow minting and burning).
     *
     * Reverts with {TokenIsNonTransferable} error if the token `id` is non-transferable.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param id The identifier of the token type to check.
     * @notice This modifier should be applied to a core function that handle single token transfers,
     * like the `_update` method in OpenZeppelin's {ERC6909} contract.
     */
    modifier tokenTransferable(address from, address to, uint256 id) {
        if (from != address(0) && to != address(0) && _transferable[id] == false) {
            revert TokenIsNonTransferable(id);
        }
        _;
    }

    /**
     * @dev Modifier to require that all token `ids` can be transferred between accounts. If either `from` or `to`
     * is the zero address, the transferability check is skipped (to allow minting and burning).
     *
     * Reverts with {TokenIsNonTransferable} error if the token `id` is non-transferable.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param ids The identifiers of the token types to check.
     * @notice This modifier should be applied to a core function that handle batch token transfers,
     * like the `_update` method in OpenZeppelin's {ERC1155} contract.
     */
    modifier allTokensTransferable(address from, address to, uint256[] memory ids) {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (from != address(0) && to != address(0) && _transferable[ids[i]] == false) {
                    revert TokenIsNonTransferable(ids[i]);
                }
            }
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenTransferable_init() internal onlyInitializing { }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenTransferable_init_unchained() internal onlyInitializing { }

    /**
     * @dev Check if a token `id` can be transferred between accounts.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the token `id` is transferable.
     */
    function isTransferable(uint256 id) public view virtual returns (bool) {
        return _transferable[id];
    }

    /**
     * @dev Sets the transferability of a given token `id`.
     *
     * @param id The token ID to configure.
     * @param transferable True if the token should be transferable, false otherwise.
     */
    function _setTransferable(uint256 id, bool transferable) internal virtual {
        _transferable[id] = transferable;
    }
}
