// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155AccessControlPrice} from "./IERC1155AccessControlPrice.sol";
import {ERC1155AccessControl} from "./ERC1155AccessControl.sol";
import {ERC1155Price} from "./extensions/ERC1155Price.sol";
import {IERC1155Base} from "./extensions/IERC1155Base.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

/**
 * @dev Extension of ERC1155AccessControl that adds price management functionality.
 * Extend this contract and either ERC1155Purchase or ERC1155PurchaseWithERC20 to add purchase functionality.
 */
abstract contract ERC1155AccessControlPrice is ERC1155AccessControl, ERC1155Price, IERC1155AccessControlPrice {
    /**
     * @dev Role required to modify the treasury address.
     */
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address, as well as
     * the `_treasury` address that will receive token purchase revenues.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        ERC1155AccessControl(initialDelay, initialDefaultAdmin, uri_)
        ERC1155Price(treasuryAccount)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC1155Price, ERC1155AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC1155AccessControlPrice).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC1155, IERC1155, ERC1155AccessControl)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /**
     * @inheritdoc IERC1155AccessControlPrice
     */
    function setPrice(uint256 id, uint256 price) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenPrice(id, price);
    }

    /**
     * @inheritdoc IERC1155AccessControlPrice
     */
    function suspendPrice(uint256 id) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _suspendTokenPrice(id);
    }

    /**
     * @inheritdoc IERC1155AccessControlPrice
     */
    function setTreasury(address payable treasuryAccount) external virtual onlyRole(TREASURER_ROLE) {
        _setTreasury(treasuryAccount);
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
     * @dev See {ERC1155-_update}.
     * Overrides to integrate price-related logic.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155, ERC1155AccessControl)
    {
        super._update(from, to, ids, values);
    }
}
