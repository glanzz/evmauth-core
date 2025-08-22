// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155X} from "src/ERC1155/ERC1155X.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with access control and role management.
 */
contract EVMAuth1155 is ERC1155X {
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
        ERC1155X(initialDelay, initialDefaultAdmin, uri_)
    {}
}
