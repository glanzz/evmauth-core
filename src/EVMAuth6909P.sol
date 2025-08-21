// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909AccessControlPurchase} from "./ERC6909/ERC6909AccessControlPurchase.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with price management and native token purchase functionality.
 * Combines access control, price management, and purchase capabilities for ERC-6909 tokens.
 */
contract EVMAuth6909P is ERC6909AccessControlPurchase {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        ERC6909AccessControlPurchase(initialDelay, initialDefaultAdmin, treasuryAccount)
    {}
}
