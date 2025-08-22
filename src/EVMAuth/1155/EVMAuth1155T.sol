// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155X} from "src/ERC1155/ERC1155X.sol";
import {ERC1155XT} from "src/ERC1155/ERC1155XT.sol";
import {TokenTTL} from "src/common/TokenTTL.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with token time-to-live (TTL) functionality.
 */
contract EVMAuth1155T is ERC1155XT {
    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The base URI for token metadata.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC1155XT(initialDelay, initialDefaultAdmin, uri_)
    {}
}
