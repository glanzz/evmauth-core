// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {EVMAuth6909P20} from "./EVMAuth6909P20.sol";
import {ERC6909TTL} from "./ERC6909/extensions/ERC6909TTL.sol";
import {ERC6909AccessControlPurchaseWithERC20} from "./ERC6909/ERC6909AccessControlPurchaseWithERC20.sol";
import {ERC6909AccessControlPrice} from "./ERC6909/ERC6909AccessControlPrice.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with price management, ERC-20 purchase functionality, and TTL.
 * Combines access control, price management, ERC-20 token purchase, and expiring token capabilities.
 */
contract EVMAuth6909TP20 is EVMAuth6909P20, ERC6909TTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        EVMAuth6909P20(initialDelay, initialDefaultAdmin, treasuryAccount)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC6909AccessControlPurchaseWithERC20, ERC6909TTL)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909AccessControlPrice, ERC6909TTL, IERC6909)
        returns (uint256)
    {
        return ERC6909TTL.balanceOf(account, id);
    }

    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909AccessControlPrice, ERC6909TTL)
    {
        ERC6909TTL._update(from, to, id, amount);
    }
}
