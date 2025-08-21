// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155AccessControlTTL} from "./ERC1155/ERC1155AccessControlTTL.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with access control and TTL.
 * Combines role-based access control with expiring token capabilities for ERC-1155 tokens.
 */
contract EVMAuth1155T is ERC1155AccessControlTTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and URI.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC1155AccessControlTTL(initialDelay, initialDefaultAdmin, uri_)
    {}
}
