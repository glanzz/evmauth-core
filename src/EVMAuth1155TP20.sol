// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {EVMAuth1155P20} from "./EVMAuth1155P20.sol";
import {ERC1155TTL} from "./ERC1155/extensions/ERC1155TTL.sol";
import {ERC1155AccessControlPurchaseWithERC20} from "./ERC1155/ERC1155AccessControlPurchaseWithERC20.sol";
import {ERC1155AccessControlPrice} from "./ERC1155/ERC1155AccessControlPrice.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with price management, ERC-20 purchase functionality, and TTL.
 * Combines access control, price management, ERC-20 token purchase, and expiring token capabilities.
 */
contract EVMAuth1155TP20 is EVMAuth1155P20, ERC1155TTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, treasury, and URI.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        EVMAuth1155P20(initialDelay, initialDefaultAdmin, treasuryAccount, uri_)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155AccessControlPurchaseWithERC20, ERC1155TTL)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC1155AccessControlPrice, ERC1155TTL, IERC1155)
        returns (uint256)
    {
        return ERC1155TTL.balanceOf(account, id);
    }

    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155AccessControlPrice)
        returns (string memory)
    {
        return ERC1155AccessControlPrice.uri(tokenId);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155AccessControlPrice, ERC1155TTL)
    {
        ERC1155TTL._update(from, to, ids, values);
    }
}
