// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909AccessControl} from "./ERC6909/ERC6909AccessControl.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features and access controls.
 * It inherits from AccessControlDefaultAdminRules to manage access control with default admin rules.
 * It supports content URIs, token metadata, token supply, and account freezing.
 */
contract EVMAuth6909 is ERC6909AccessControl {
    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin)
        ERC6909AccessControl(initialDelay, initialDefaultAdmin)
    {}
}
