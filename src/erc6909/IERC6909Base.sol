// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {
    IERC6909,
    IERC6909ContentURI,
    IERC6909Metadata,
    IERC6909TokenSupply
} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with extended features.
 * This interface consolidates IERC6909 with the ContentURI, Metadata, and TokenSupply extensions.
 */
interface IERC6909Base is IERC6909, IERC6909ContentURI, IERC6909Metadata, IERC6909TokenSupply {}
