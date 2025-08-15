// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6906AccessControl} from "./IERC6906AccessControl.sol";
import {ERC6909Base} from "./extensions/ERC6909Base.sol";
import {ERC6909TTL} from "./extensions/ERC6909TTL.sol";
import {ERC6909Price} from "./extensions/ERC6909Price.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features and access controls.
 * It supports expiring tokens, purchasable tokens, content URIs, token metadata, and token supply.
 * It inherits from AccessControlDefaultAdminRules to manage access control with default admin rules.
 * Extend this contract and either ERC6909Purchase or ERC6909PurchaseWithERC20 to add purchase functionality.
 */
abstract contract ERC6906AccessControl is AccessControlDefaultAdminRules, ERC6909Base, ERC6909TTL, ERC6909Price {
    // Role required to manage token metadata and content URIs
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    // Role required to mint new tokens
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER_ROLE");

    // Role required to burn tokens
    bytes32 public constant TOKEN_BURNER_ROLE = keccak256("TOKEN_BURNER_ROLE");

    // Role required to modify the treasury address and set token prices
    bytes32 public constant FINANCE_MANAGER_ROLE = keccak256("FINANCE_MANAGER_ROLE");

    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address, as well as
     * the `_treasury` address that will receive token purchase revenues.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        AccessControlDefaultAdminRules(initialDelay, initialDefaultAdmin)
        ERC6909Price(treasuryAccount)
    {
        // Initialize the contract with the provided admin and default admin addresses.
        // The treasury address is set for handling purchase revenues.
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlDefaultAdminRules, ERC6909Base, ERC6909TTL, ERC6909Price)
        returns (bool)
    {
        return interfaceId == type(IERC6906AccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909, IERC6909, ERC6909TTL)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /**
     * @dev Sets the `contractURI` for the contract.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setContractURI(string memory contractURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setContractURI(contractURI);
    }

    /**
     * @dev Sets the `tokenURI` for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenURI(uint256 id, string memory tokenURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenURI(id, tokenURI);
    }

    /**
     * @dev Sets the name for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenName(uint256 id, string memory name) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setName(id, name);
    }

    /**
     * @dev Sets the symbol for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenSymbol(uint256 id, string memory symbol) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setSymbol(id, symbol);
    }

    /**
     * @dev Sets the decimals for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenDecimals(uint256 id, uint8 decimals) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setDecimals(id, decimals);
    }

    /**
     * @dev Sets the TTL for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenTTL(id, ttl);
    }

    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `FINANCE_MANAGER_ROLE`.
     */
    function setTokenPrice(uint256 id, uint256 price) external virtual onlyRole(FINANCE_MANAGER_ROLE) {
        _setTokenPrice(id, price);
    }

    /**
     * @dev Sets the treasury address that will receive token purchase revenues.
     *
     * Requirements:
     * - The caller must have the `FINANCE_MANAGER_ROLE`.
     */
    function setTreasury(address payable treasuryAccount) external virtual onlyRole(FINANCE_MANAGER_ROLE) {
        _setTreasury(treasuryAccount);
    }

    /**
     * @dev Mints `amount` of token type `id` to `to`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount) external virtual onlyRole(TOKEN_MINTER_ROLE) returns (bool) {
        _mint(to, id, amount);
        return true;
    }

    /**
     * @dev Burns `amount` of token type `id` from `from`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_BURNER_ROLE`.
     */
    function burn(address from, uint256 id, uint256 amount)
        external
        virtual
        onlyRole(TOKEN_BURNER_ROLE)
        returns (bool)
    {
        _burn(from, id, amount);
        return true;
    }

    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909, ERC6909Base, ERC6909TTL)
    {
        super._update(from, to, id, amount);
    }
}
