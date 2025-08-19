// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155Price} from "./ERC1155Price.sol";
import {IERC1155PurchaseWithERC20} from "./IERC1155PurchaseWithERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract that supports the direct purchase of tokens
 * using ERC-20 tokens (e.g. USDC, USDT).
 */
abstract contract ERC1155PurchaseWithERC20 is ERC1155Price, IERC1155PurchaseWithERC20, Pausable {
    // Import SafeERC20 to revert if a transfer returns false
    using SafeERC20 for IERC20;

    // Mapping of supported ERC-20 token addresses
    mapping(address => bool) private _paymentTokens;

    // Array to track all supported tokens for enumeration
    address[] private _paymentTokensList;

    // Errors
    error ERC1155PriceInsufficientERC20PaymentTokenAllowance(address token, uint256 required, uint256 allowance);
    error ERC1155PriceInsufficientERC20PaymentTokenBalance(address token, uint256 required, uint256 balance);
    error ERC1155PriceInvalidERC20PaymentToken(address token);

    /**
     * @dev Sets the initial `_treasury` address that will receive token purchase revenues.
     *
     * @param treasuryAccount The address where purchase revenues will be sent
     */
    constructor(address payable treasuryAccount) ERC1155Price(treasuryAccount) {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Price, IERC165) returns (bool) {
        return interfaceId == type(IERC1155PurchaseWithERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155PurchaseWithERC20
    function purchaseWithERC20(address paymentToken, uint256 id, uint256 amount)
        external
        virtual
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseWithERC20For(paymentToken, _msgSender(), id, amount);

        return true;
    }

    /// @inheritdoc IERC1155PurchaseWithERC20
    function purchaseWithERC20For(address paymentToken, address receiver, uint256 id, uint256 amount)
        external
        virtual
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseWithERC20For(paymentToken, receiver, id, amount);

        return true;
    }

    /// @inheritdoc IERC1155PurchaseWithERC20
    function acceptedERC20PaymentTokens() external view returns (address[] memory) {
        return _paymentTokensList;
    }

    /// @inheritdoc IERC1155PurchaseWithERC20
    function isERC20PaymentTokenAccepted(address token) external view returns (bool) {
        return _paymentTokens[token];
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
     * It validates the purchase, checks token support and balance/allowance, transfers tokens to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The ERC-20 payment token must be accepted.
     * - The caller must have sufficient balance for the ERC-20 token.
     * - The caller must have approved the contract to spend the required amount of ERC-20 tokens.
     *
     * @param paymentToken The address of the ERC-20 token to use for payment.
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseWithERC20For(address paymentToken, address receiver, uint256 id, uint256 amount)
        internal
        virtual
    {
        if (!_paymentTokens[paymentToken]) {
            revert ERC1155PriceInvalidERC20PaymentToken(paymentToken);
        }

        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        IERC20 erc20Token = IERC20(paymentToken);

        // Check balance
        uint256 balance = erc20Token.balanceOf(_msgSender());
        if (balance < totalPrice) {
            revert ERC1155PriceInsufficientERC20PaymentTokenBalance(paymentToken, totalPrice, balance);
        }

        // Check allowance
        uint256 allowance = erc20Token.allowance(_msgSender(), address(this));
        if (allowance < totalPrice) {
            revert ERC1155PriceInsufficientERC20PaymentTokenAllowance(paymentToken, totalPrice, allowance);
        }

        // Transfer ERC-20 tokens from purchaser to treasury
        erc20Token.safeTransferFrom(_msgSender(), _getTreasury(), totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }

    /**
     * @dev Adds an ERC-20 token to the list of accepted payment tokens.
     * If the token is already accepted, this function has no effect.
     *
     * Emits a {ERC20PaymentTokenAdded} event upon successful addition.
     *
     * Revert if the token address is zero.
     *
     * @param token The address of the ERC-20 token to add as a payment option.
     */
    function _addERC20PaymentToken(address token) internal {
        if (token == address(0)) {
            revert ERC1155PriceInvalidERC20PaymentToken(token);
        }
        if (_paymentTokens[token]) {
            return; // Token already accepted
        }

        _paymentTokens[token] = true;
        _paymentTokensList.push(token);

        emit ERC20PaymentTokenAdded(token);
    }

    /**
     * @dev Removes an ERC-20 token from the list of accepted payment tokens.
     * If the token is not accepted, this function has no effect.
     *
     * Emits a {ERC20PaymentTokenRemoved} event upon successful removal.
     *
     * @param token The address of the ERC-20 token to remove from the accepted payment tokens.
     */
    function _removeERC20PaymentToken(address token) internal {
        if (!_paymentTokens[token]) {
            return; // Token not accepted
        }

        if (_paymentTokens[token]) {
            _paymentTokens[token] = false;

            // Remove from array
            for (uint256 i = 0; i < _paymentTokensList.length; i++) {
                if (_paymentTokensList[i] == token) {
                    _paymentTokensList[i] = _paymentTokensList[_paymentTokensList.length - 1];
                    _paymentTokensList.pop();
                    break;
                }
            }

            emit ERC20PaymentTokenRemoved(token);
        }
    }
}