// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909X} from "src/ERC6909/ERC6909X.sol";
import {ERC6909XT} from "src/ERC6909/ERC6909XT.sol";
import {TokenTTL} from "src/common/TokenTTL.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with token time-to-live (TTL) functionality.
 */
contract EVMAuth6909T is ERC6909XT {
    /**
     * @dev Initializes the contract with an initial delay, default admin address, and URI.
     *
     * @param initialDelay The initial delay for transfer of the default admin role.
     * @param initialDefaultAdmin The address of the initial default admin.
     * @param uri_ The contract URI.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC6909XT(initialDelay, initialDefaultAdmin, uri_)
    {}
}
