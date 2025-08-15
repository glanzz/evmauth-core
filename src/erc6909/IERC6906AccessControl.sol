// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909TTL} from "./extensions/IERC6909TTL.sol";
import {IERC6909Price} from "./extensions/IERC6909Price.sol";
import {
    IERC6909ContentURI,
    IERC6909Metadata,
    IERC6909TokenSupply
} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

/**
 * @dev Interface of an ERC-6909 compliant contract with extended features and access controls.
 */
interface IERC6906AccessControl is
    IAccessControlDefaultAdminRules,
    IERC6909TTL,
    IERC6909Price,
    IERC6909ContentURI,
    IERC6909Metadata,
    IERC6909TokenSupply
{
    /**
     * @dev Role required to manage token metadata and content URIs.
     */
    function TOKEN_MANAGER_ROLE() external view returns (bytes32);

    /**
     * @dev Role required to mint new tokens.
     */
    function TOKEN_MINTER_ROLE() external view returns (bytes32);

    /**
     * @dev Role required to burn tokens.
     */
    function TOKEN_BURNER_ROLE() external view returns (bytes32);

    /**
     * @dev Role required to modify the treasury address and set token prices.
     */
    function FINANCE_MANAGER_ROLE() external view returns (bytes32);

    /**
     * @dev Sets the `contractURI` for the contract.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Sets the `tokenURI` for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenURI(uint256 id, string memory tokenURI) external;

    /**
     * @dev Sets the name for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenName(uint256 id, string memory name) external;

    /**
     * @dev Sets the symbol for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenSymbol(uint256 id, string memory symbol) external;

    /**
     * @dev Sets the decimals for a given token of type `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTokenDecimals(uint256 id, uint8 decimals) external;

    /**
     * @dev Sets the TTL for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MANAGER_ROLE`.
     */
    function setTTL(uint256 id, uint256 ttl) external;

    /**
     * @dev Sets the price for a specific token `id`.
     *
     * Requirements:
     * - The caller must have the `FINANCE_MANAGER_ROLE`.
     */
    function setTokenPrice(uint256 id, uint256 price) external;

    /**
     * @dev Sets the treasury address that will receive token purchase revenues.
     *
     * Requirements:
     * - The caller must have the `FINANCE_MANAGER_ROLE`.
     */
    function setTreasury(address payable treasuryAccount) external;

    /**
     * @dev Mints `amount` of token type `id` to `to`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev Burns `amount` of token type `id` from `from`.
     *
     * Requirements:
     * - The caller must have the `TOKEN_BURNER_ROLE`.
     */
    function burn(address from, uint256 id, uint256 amount) external returns (bool);
}
