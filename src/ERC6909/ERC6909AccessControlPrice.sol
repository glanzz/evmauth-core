// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909AccessControlPrice} from "./IERC6909AccessControlPrice.sol";
import {ERC6909AccessControl} from "./ERC6909AccessControl.sol";
import {ERC6909Base} from "./extensions/ERC6909Base.sol";
import {ERC6909Price} from "./extensions/ERC6909Price.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features and access controls.
 * It inherits from ERC6909AccessControl to manage access control with default admin rules.
 * It supports purchasable tokens, content URIs, token metadata, and token supply, and account freezing.
 * Extend this contract and either ERC6909Purchase or ERC6909PurchaseWithERC20 to add purchase functionality.
 */
contract ERC6909AccessControlPrice is ERC6909Price, ERC6909AccessControl, IERC6909AccessControlPrice {
    /**
     * @dev Role required to modify the treasury address.
     */
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address, as well as
     * the `_treasury` address that will receive token purchase revenues.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        ERC6909AccessControl(initialDelay, initialDefaultAdmin)
        ERC6909Price(treasuryAccount)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC6909Price, ERC6909AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC6909AccessControlPrice).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC6909
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909, IERC6909, ERC6909AccessControl)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /**
     * @inheritdoc IERC6909AccessControlPrice
     */
    function setPrice(uint256 id, uint256 price) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenPrice(id, price);
    }

    /**
     * @inheritdoc IERC6909AccessControlPrice
     */
    function suspendPrice(uint256 id) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _suspendTokenPrice(id);
    }

    /**
     * @inheritdoc IERC6909AccessControlPrice
     */
    function setTreasury(address payable treasuryAccount) external virtual onlyRole(TREASURER_ROLE) {
        _setTreasury(treasuryAccount);
    }

    /// @inheritdoc ERC6909AccessControl
    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909, ERC6909AccessControl)
    {
        super._update(from, to, id, amount);
    }
}
