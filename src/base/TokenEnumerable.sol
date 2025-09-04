// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev Abstract contract that provides sequential token ID tracking and existence checking.
 */
abstract contract TokenEnumerable is ContextUpgradeable {
    /**
     * @dev The next token ID to be assigned.
     */
    uint256 private _nextTokenID;

    /**
     * @dev Error thrown when an operation is attempted on a non-existent ID.
     */
    error InvalidTokenID(uint256 id);

    /**
     * @dev Modifier to ensure a given token `id` exists.
     *
     * Reverts with {InvalidTokenID} error if the `id` has not yet been claimed.
     *
     * @param id The token ID to check.
     */
    modifier tokenExists(uint256 id) {
        if (!isValid(id)) {
            revert InvalidTokenID(id);
        }
        _;
    }

    /**
     * @dev Modifier to ensure all given token `ids` exist.
     *
     * Reverts with {InvalidTokenID} error if any of the `ids` have not yet been claimed.
     *
     * @param ids The array of IDs to check.
     */
    modifier allTokensExist(uint256[] memory ids) {
        for (uint256 i = 0; i < ids.length; i++) {
            if (!isValid(ids[i])) {
                revert InvalidTokenID(ids[i]);
            }
        }
        _;
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     */
    function __TokenEnumerable_init() internal onlyInitializing {
        __Context_init();
        __TokenEnumerable_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __TokenEnumerable_init_unchained() internal onlyInitializing {
        _nextTokenID = 1; // Start token IDs at 1
    }

    /**
     * @dev Returns the next token ID to be assigned.
     *
     * @return uint256 The next token ID.
     */
    function nextTokenID() public view returns (uint256) {
        return _nextTokenID;
    }

    /**
     * @dev Checks if an `id` exists (i.e. has been claimed).
     *
     * @param id The token ID to check.
     * @return bool indicating whether the token exists.
     */
    function isValid(uint256 id) public view virtual returns (bool) {
        return id > 0 && id < _nextTokenID;
    }

    /**
     * @dev Claims the next sequential token ID. The value of `_nextTokenID` is incremented after assignment.
     *
     * @return tokenId The ID of the configured token.
     */
    function _claimNextTokenID() internal virtual returns (uint256) {
        uint256 id = _nextTokenID;

        _nextTokenID++;

        return id;
    }
}
