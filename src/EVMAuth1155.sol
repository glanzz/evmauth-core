// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155AccessControl} from "./ERC1155/ERC1155AccessControl.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features and access controls.
 * It inherits from AccessControlDefaultAdminRules to manage access control with default admin rules.
 * It supports URIs, token supply tracking, and account freezing.
 */
contract EVMAuth1155 is ERC1155AccessControl {
    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC1155AccessControl(initialDelay, initialDefaultAdmin, uri_)
    {}
}
