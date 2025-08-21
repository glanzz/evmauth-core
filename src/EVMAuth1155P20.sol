// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155AccessControlPurchaseWithERC20} from "./ERC1155/ERC1155AccessControlPurchaseWithERC20.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with price management and ERC-20 token purchase functionality.
 * Combines access control, price management, and ERC-20 purchase capabilities for ERC-1155 tokens.
 */
contract EVMAuth1155P20 is ERC1155AccessControlPurchaseWithERC20 {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        ERC1155AccessControlPurchaseWithERC20(initialDelay, initialDefaultAdmin, treasuryAccount, uri_)
    {}
}
