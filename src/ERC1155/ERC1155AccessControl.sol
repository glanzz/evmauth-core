// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC1155AccessControl} from "./IERC1155AccessControl.sol";
import {IERC1155Base} from "./extensions/IERC1155Base.sol";
import {ERC1155Base} from "./extensions/ERC1155Base.sol";
import {ERC1155TTL} from "./extensions/ERC1155TTL.sol";
import {ERC1155Price} from "./extensions/ERC1155Price.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract with extended features and access controls.
 * It supports expiring tokens, purchasable tokens, URIs, and token supply tracking.
 * It inherits from AccessControlDefaultAdminRules to manage access control with default admin rules.
 * Extend this contract and either ERC1155Purchase or ERC1155PurchaseWithERC20 to add purchase functionality.
 */
contract ERC1155AccessControl is
    AccessControlDefaultAdminRules,
    ERC1155Base,
    ERC1155TTL,
    ERC1155Price,
    IERC1155AccessControl
{
    /**
     * @dev Role required to pause/un-pause the contract, freeze accounts, and manage the allowlist.
     */
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");

    /**
     * @dev Role required to manage token configuration, metadata, and URIs.
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

    // Errors
    error ERC1155AccessControlAccountFrozen(address account);
    error ERC1155AccessControlInvalidAddress(address account);

    /**
     * @dev Sets the initial values for `defaultAdminDelay` and `defaultAdmin` address, as well as
     * the `_treasury` address that will receive token purchase revenues.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        AccessControlDefaultAdminRules(initialDelay, initialDefaultAdmin)
        ERC1155Base(uri_)
        ERC1155Price(treasuryAccount)
    {
        // Initialize the contract with the provided admin and default admin addresses.
        // The treasury address is set for handling purchase revenues.
        // The URI is set as the base URI for all tokens.
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC1155Base, ERC1155TTL, ERC1155Price, AccessControlDefaultAdminRules)
        returns (bool)
    {
        return interfaceId == type(IERC1155AccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override(ERC1155, IERC1155, ERC1155TTL)
        returns (uint256)
    {
        return super.balanceOf(account, id);
    }

    /// @inheritdoc IERC1155Base
    function isTransferable(uint256 id) public view virtual override(IERC1155Base, ERC1155Base) returns (bool) {
        return super.isTransferable(id);
    }

    /// @inheritdoc IERC1155Base
    function totalSupply(uint256 id) public view virtual override(IERC1155Base, ERC1155Base) returns (uint256) {
        return ERC1155Base.totalSupply(id);
    }

    /// @inheritdoc IERC1155Base
    function totalSupply() public view virtual override(IERC1155Base, ERC1155Base) returns (uint256) {
        return ERC1155Base.totalSupply();
    }

    /// @inheritdoc IERC1155Base
    function exists(uint256 id) public view virtual override(IERC1155Base, ERC1155Base) returns (bool) {
        return ERC1155Base.exists(id);
    }

    /// @inheritdoc IERC1155MetadataURI
    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155Base, IERC1155MetadataURI)
        returns (string memory)
    {
        return ERC1155Base.uri(tokenId);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function isFrozen(address account) external view virtual returns (bool) {
        return _frozenAccounts[account];
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function frozenAccounts() external view virtual returns (address[] memory) {
        return _frozenList;
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function freezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        if (account == address(0)) {
            revert ERC1155AccessControlInvalidAddress(account);
        }
        if (!_frozenAccounts[account]) {
            _frozenAccounts[account] = true;
            _frozenList.push(account);
            emit AccountStatusUpdate(account, ACCOUNT_FROZEN_STATUS);
        }
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function unfreezeAccount(address account) external virtual onlyRole(ACCESS_MANAGER_ROLE) {
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
     * @inheritdoc IERC1155AccessControl
     */
    function pause() external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        _pause();
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function unpause() external virtual onlyRole(ACCESS_MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setURI(string memory newuri) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setURI(newuri);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setTokenURI(uint256 id, string memory tokenURI) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setURI(id, tokenURI);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setTTL(uint256 id, uint256 ttl) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenTTL(id, ttl);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setPrice(uint256 id, uint256 price) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setTokenPrice(id, price);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function suspendPrice(uint256 id) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _suspendTokenPrice(id);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setNonTransferable(uint256 id, bool nonTransferable) external virtual onlyRole(TOKEN_MANAGER_ROLE) {
        _setNonTransferable(id, nonTransferable);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function setTreasury(address payable treasuryAccount) external virtual onlyRole(TREASURER_ROLE) {
        _setTreasury(treasuryAccount);
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function mint(address to, uint256 id, uint256 amount) external virtual onlyRole(MINTER_ROLE) returns (bool) {
        _mint(to, id, amount, "");
        return true;
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        external
        virtual
        onlyRole(MINTER_ROLE)
        returns (bool)
    {
        _mintBatch(to, ids, amounts, "");
        return true;
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function burn(address from, uint256 id, uint256 amount) external virtual onlyRole(BURNER_ROLE) returns (bool) {
        _burn(from, id, amount);
        return true;
    }

    /**
     * @inheritdoc IERC1155AccessControl
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts)
        external
        virtual
        onlyRole(BURNER_ROLE)
        returns (bool)
    {
        _burnBatch(from, ids, amounts);
        return true;
    }

    /**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits {TransferSingle} or {TransferBatch} events.
     *
     * Requirements:
     * - Neither `from` nor `to` address can be frozen.
     * - if `from` is the zero address, `to` must not be the zero address (minting).
     * - if `to` is the zero address, `from` must not be the zero address (burning).
     * - if both `from` and `to` are non-zero, token `ids` must be transferable.
     * - if both `from` and `to` are non-zero, `from` must have enough balance to cover `values`.
     * - if `from` and `to` are the same, it does nothing.
     *
     * @param from The address to transfer tokens from. If zero, it mints tokens to `to`.
     * @param to The address to transfer tokens to. If zero, it burns tokens from `from`.
     * @param ids The identifiers of the token types to transfer.
     * @param values The numbers of tokens to transfer.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override(ERC1155, ERC1155Base, ERC1155TTL)
    {
        if (_frozenAccounts[from]) {
            revert ERC1155AccessControlAccountFrozen(from);
        }
        if (_frozenAccounts[to]) {
            revert ERC1155AccessControlAccountFrozen(to);
        }
        super._update(from, to, ids, values);
    }
}
