// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155AccessControlPurchase} from "./ERC1155/ERC1155AccessControlPurchase.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with price management and native token purchase functionality.
 * Combines access control, price management, and purchase capabilities for ERC-1155 tokens.
 */
contract EVMAuth1155P is ERC1155AccessControlPurchase {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        ERC1155AccessControlPurchase(initialDelay, initialDefaultAdmin, treasuryAccount, uri_)
    {}
}
