// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909AccessControl} from "./IERC6909AccessControl.sol";
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
contract ERC6909AccessControl is
    AccessControlDefaultAdminRules,
    ERC6909Base,
    ERC6909TTL,
    ERC6909Price,
    IERC6909AccessControl
{
    /**
     * @dev Role required to pause/un-pause the contract, freeze accounts, and  manage the allowlist.
     */
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");

    /**
     * @dev Role required to manage token configuration, metadata, and content URIs.
     */
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    /**
     * @dev Role required to mint new tokens.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Role required to burn tokens.
     */
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Role required to modify the treasury address.
     */
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /**
     * @dev Status indicating an account should not be allowed to purchase, transfer, or receive tokens.
     */
    bytes32 public constant ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");

    /**
     * @dev Status indicating an account is no longer frozen.
     */
    bytes32 public constant ACCOUNT_UNFROZEN_STATUS = keccak256("ACCOUNT_UNFROZEN_STATUS");

    // Account => AccountStatus mapping (to track frozen accounts)
    mapping(address => bool) private _frozenAccounts;

    // Array of frozen accounts (to track all frozen accounts)
    address[] private _frozenList;

    // Token ID => is non-transferable mapping (tokens are transferable by default)
    mapping(uint256 => bool) private _nonTransferableTokens;

    // Errors
    error ERC6909AccessControlAccountFrozen(address account);
    error ERC6909AccessControlNonTransferableToken(uint256 id);

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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC6909Base, ERC6909TTL, ERC6909Price, AccessControlDefaultAdminRules)
        returns (bool)
    {
        return interfaceId == type(IERC6909AccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC6909, IERC6909, ERC6909TTL)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /// @inheritdoc IERC6909AccessControl
    function isTransferable(uint256 id) external view virtual returns (bool) {
        return !_nonTransferableTokens[id];
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function isFrozen(address account) external view virtual returns (bool) {
        return _frozenAccounts[account];
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function frozenAccounts() external view virtual returns (address[] memory) {
        return _frozenList;
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function freezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        if (account == address(0)) {
            revert("ERC6909AccessControl: Cannot freeze the zero address");
        }
        if (!_frozenAccounts[account]) {
            _frozenAccounts[account] = true;
            _frozenList.push(account);
            emit AccountStatusUpdate(account, ACCOUNT_FROZEN_STATUS);
        }
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function unfreezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        if (account == address(0)) {
            revert("ERC6909AccessControl: Cannot unfreeze the zero address");
        }
        if (_frozenAccounts[account]) {
            _frozenAccounts[account] = false;
            // Remove the account from the frozen list
            for (uint256 i = 0; i < _frozenList.length; i++) {
                if (_frozenList[i] == account) {
                    _frozenList[i] = _frozenList[_frozenList.length - 1]; // Replace with the last element
                    _frozenList.pop(); // Remove the last element
                    break;
                }
            }
            emit AccountStatusUpdate(account, ACCOUNT_UNFROZEN_STATUS);
        }
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function pause() external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        _pause();
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function unpause() external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setContractURI(string memory contractURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setContractURI(contractURI);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTokenURI(uint256 id, string memory tokenURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenURI(id, tokenURI);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTokenName(uint256 id, string memory name) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setName(id, name);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTokenSymbol(uint256 id, string memory symbol) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setSymbol(id, symbol);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTokenDecimals(uint256 id, uint8 decimals) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setDecimals(id, decimals);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenTTL(id, ttl);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setPrice(uint256 id, uint256 price) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenPrice(id, price);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setNonTransferable(uint256 id, bool nonTransferable) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _nonTransferableTokens[id] = nonTransferable;
        emit ERC6909NonTransferableUpdated(id, nonTransferable);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function setTreasury(address payable treasuryAccount) external virtual onlyRole(TREASURER_ROLE) {
        _setTreasury(treasuryAccount);
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function mint(address to, uint256 id, uint256 amount) external virtual onlyRole(MINTER_ROLE) returns (bool) {
        _mint(to, id, amount);
        return true;
    }

    /**
     * @inheritdoc IERC6909AccessControl
     */
    function burn(address from, uint256 id, uint256 amount) external virtual onlyRole(BURNER_ROLE) returns (bool) {
        _burn(from, id, amount);
        return true;
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     * - Neither `from` nor `to` address can be frozen.
     * - if `from` is the zero address, `to` must not be the zero address (minting).
     * - if `to` is the zero address, `from` must not be the zero address (burning).
     * - if both `from` and `to` are non-zero, token `id` must be transferable.
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `amount`.
     * - if `from` and `to` are the same, it does nothing.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param id The identifier of the token type to transfer.
     * @param amount The number of tokens to transfer.
     */
    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909, ERC6909Base, ERC6909TTL)
    {
        if (_frozenAccounts[from]) {
            revert ERC6909AccessControlAccountFrozen(from);
        }
        if (_frozenAccounts[to]) {
            revert ERC6909AccessControlAccountFrozen(to);
        }
        if (from != address(0) && to != address(0) && _nonTransferableTokens[id]) {
            revert ERC6909AccessControlNonTransferableToken(id);
        }
        super._update(from, to, id, amount);
    }
}
