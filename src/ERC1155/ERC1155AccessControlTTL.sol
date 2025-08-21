// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155AccessControlTTL} from "./IERC1155AccessControlTTL.sol";
import {ERC1155AccessControl} from "./ERC1155AccessControl.sol";
import {ERC1155TTL} from "./extensions/ERC1155TTL.sol";
import {IERC1155Base} from "./extensions/IERC1155Base.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

/**
 * @dev Extension of ERC1155AccessControl that adds time-to-live (TTL) functionality for expiring tokens.
 */
contract ERC1155AccessControlTTL is ERC1155AccessControl, ERC1155TTL, IERC1155AccessControlTTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        ERC1155AccessControl(initialDelay, initialDefaultAdmin, uri_)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC1155TTL, ERC1155AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC1155AccessControlTTL).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(IERC1155, ERC1155TTL, ERC1155AccessControl)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /// @inheritdoc IERC1155Base
    function isTransferable(uint256 id)
        public
        view
        virtual
        override(IERC1155Base, ERC1155AccessControl)
        returns (bool)
    {
        return super.isTransferable(id);
    }

    /// @inheritdoc IERC1155Base
    function totalSupply(uint256 id)
        public
        view
        virtual
        override(IERC1155Base, ERC1155AccessControl)
        returns (uint256)
    {
        return super.totalSupply(id);
    }

    /// @inheritdoc IERC1155Base
    function totalSupply() public view virtual override(IERC1155Base, ERC1155AccessControl) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IERC1155Base
    function exists(uint256 id) public view virtual override(IERC1155Base, ERC1155AccessControl) returns (bool) {
        return super.exists(id);
    }

    /// @inheritdoc IERC1155MetadataURI
    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155AccessControl, IERC1155MetadataURI)
        returns (string memory)
    {
        return super.uri(tokenId);
    }

    /**
     * @inheritdoc IERC1155AccessControlTTL
     */
    function setTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenTTL(id, ttl);
    }

    /**
     * @dev See {ERC1155-_update}.
     * Overrides to integrate TTL-related logic.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155TTL, ERC1155AccessControl)
    {
        super._update(from, to, ids, values);
    }
}
