// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

/**
 * @dev Interface of an ERC-1155 compliant contract with extended features.
 * This interface consolidates IERC1155 with metadata and supply extensions,
 * plus non-transferable token functionality.
 */
interface IERC1155Base is IERC1155, IERC1155MetadataURI {
    /**
     * @dev Emitted when the non-transferable status of a token `id` is updated.
     */
    event ERC1155NonTransferableUpdated(uint256 indexed id, bool nonTransferable);

    /**
     * @dev Check if a token `id` can be transferred between accounts.
     *
     * @param id The identifier of the token type to check.
     * @return bool indicating whether the token `id` is transferable.
     */
    function isTransferable(uint256 id) external view returns (bool);

    /**
     * @dev Total value of tokens in with a given id.
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @dev Total value of tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Indicates whether any token exists with a given id, or not.
     */
    function exists(uint256 id) external view returns (bool);
}
