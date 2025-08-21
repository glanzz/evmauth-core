// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909AccessControlTTL} from "./IERC6909AccessControlTTL.sol";
import {ERC6909AccessControl} from "./ERC6909AccessControl.sol";
import {ERC6909Base} from "./extensions/ERC6909Base.sol";
import {ERC6909TTL} from "./extensions/ERC6909TTL.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features and access controls.
 * It inherits from ERC6909AccessControl to manage access control with default admin rules.
 * It supports expiring tokens, content URIs, token metadata, and token supply, and account freezing.
 */
contract ERC6909AccessControlTTL is ERC6909AccessControl, ERC6909TTL, IERC6909AccessControlTTL {
    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin)
        ERC6909AccessControl(initialDelay, initialDefaultAdmin)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC6909TTL, ERC6909AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC6909AccessControlTTL).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC6909
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(IERC6909, ERC6909TTL, ERC6909AccessControl)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /**
     * @inheritdoc IERC6909AccessControlTTL
     */
    function setTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenTTL(id, ttl);
    }

    /// @inheritdoc ERC6909AccessControl
    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909TTL, ERC6909AccessControl)
    {
        super._update(from, to, id, amount);
    }
}
