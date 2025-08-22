// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909X} from "src/ERC6909/ERC6909X.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with access control and role management.
 */
contract EVMAuth6909 is ERC6909X {
    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     * The `initialDelay` is used to set the delay for transfer of the default admin role.
     * The `initialDefaultAdmin` is the address that will have the default admin role.
     * The `uri_` is the base URI for the token metadata.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The base URI for token metadata.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC6909X(initialDelay, initialDefaultAdmin, uri_)
    {}
}
