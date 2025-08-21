// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909AccessControlPurchaseWithERC20} from "./ERC6909/ERC6909AccessControlPurchaseWithERC20.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with price management and ERC-20 token purchase functionality.
 * Combines access control, price management, and ERC-20 purchase capabilities for ERC-6909 tokens.
 */
contract EVMAuth6909P20 is ERC6909AccessControlPurchaseWithERC20 {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        ERC6909AccessControlPurchaseWithERC20(initialDelay, initialDefaultAdmin, treasuryAccount)
    {}
}
