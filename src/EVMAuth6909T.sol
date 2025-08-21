// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909AccessControlTTL} from "./ERC6909/ERC6909AccessControlTTL.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with access control and TTL.
 * Combines role-based access control with expiring token capabilities for ERC-6909 tokens.
 */
contract EVMAuth6909T is ERC6909AccessControlTTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin)
        ERC6909AccessControlTTL(initialDelay, initialDefaultAdmin)
    {}
}
