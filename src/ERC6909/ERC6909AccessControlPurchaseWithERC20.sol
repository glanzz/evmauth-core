// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC6909AccessControlPrice} from "./ERC6909AccessControlPrice.sol";
import {IERC6909PurchaseWithERC20} from "./extensions/IERC6909PurchaseWithERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Extension of ERC6909AccessControlPrice that adds ERC20 token purchase functionality.
 * This avoids diamond inheritance by extending AccessControlPrice and implementing purchase methods.
 */
abstract contract ERC6909AccessControlPurchaseWithERC20 is ERC6909AccessControlPrice, IERC6909PurchaseWithERC20 {
    // Import SafeERC20 to revert if a transfer returns false
    using SafeERC20 for IERC20;

    // Mapping of supported ERC-20 token addresses
    mapping(address => bool) private _paymentTokens;

    // Array to track all supported tokens for enumeration
    address[] private _paymentTokensList;

    // Errors
    error ERC6909PriceInsufficientERC20PaymentTokenAllowance(address token, uint256 required, uint256 allowance);
    error ERC6909PriceInsufficientERC20PaymentTokenBalance(address token, uint256 required, uint256 balance);
    error ERC6909PriceInvalidERC20PaymentToken(address token);

    // Events are inherited from IERC6909PurchaseWithERC20

    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount)
        ERC6909AccessControlPrice(initialDelay, initialDefaultAdmin, treasuryAccount)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC6909AccessControlPrice, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC6909PurchaseWithERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909PurchaseWithERC20
    function acceptedERC20PaymentTokens() external view virtual override returns (address[] memory) {
        return _paymentTokensList;
    }

    /// @inheritdoc IERC6909PurchaseWithERC20
    function isERC20PaymentTokenAccepted(address token) public view virtual override returns (bool) {
        return _paymentTokens[token];
    }

    /// @inheritdoc IERC6909PurchaseWithERC20
    function purchaseWithERC20(address token, uint256 id, uint256 amount)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseWithERC20For(token, msg.sender, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909PurchaseWithERC20
    function purchaseWithERC20For(address token, address receiver, uint256 id, uint256 amount)
        external
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseWithERC20For(token, receiver, id, amount);
        return true;
    }

    /**
     * @dev Internal function to handle the purchase logic with ERC-20 tokens.
     * It validates the purchase, checks payment token acceptance and sufficiency,
     * transfers funds to treasury, and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The payment token must be in the accepted list.
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The buyer must have sufficient ERC-20 token balance.
     * - The buyer must have approved sufficient ERC-20 tokens for this contract.
     *
     * @param token The ERC-20 token address to use for payment.
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseWithERC20For(address token, address receiver, uint256 id, uint256 amount) internal virtual {
        if (!isERC20PaymentTokenAccepted(token)) {
            revert ERC6909PriceInvalidERC20PaymentToken(token);
        }

        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        if (totalPrice > 0) {
            IERC20 paymentToken = IERC20(token);
            uint256 balance = paymentToken.balanceOf(msg.sender);
            if (balance < totalPrice) {
                revert ERC6909PriceInsufficientERC20PaymentTokenBalance(token, totalPrice, balance);
            }

            uint256 allowance = paymentToken.allowance(msg.sender, address(this));
            if (allowance < totalPrice) {
                revert ERC6909PriceInsufficientERC20PaymentTokenAllowance(token, totalPrice, allowance);
            }

            // Transfer ERC-20 tokens from buyer to treasury
            paymentToken.safeTransferFrom(msg.sender, _getTreasury(), totalPrice);
        }

        _mint(receiver, id, amount);

        emit Purchase(msg.sender, receiver, id, amount, totalPrice);
    }

    /**
     * @dev Adds an ERC-20 token to the list of accepted payment tokens.
     * Requirements:
     * - The token address must not be zero.
     *
     * @param token The address of the ERC-20 token to add.
     */
    function _addERC20PaymentToken(address token) internal virtual {
        if (token == address(0)) {
            revert ERC6909PriceInvalidERC20PaymentToken(token);
        }
        if (!_paymentTokens[token]) {
            _paymentTokens[token] = true;
            _paymentTokensList.push(token);
            emit ERC20PaymentTokenAdded(token);
        }
    }

    /**
     * @dev Removes an ERC-20 token from the list of accepted payment tokens.
     *
     * @param token The address of the ERC-20 token to remove.
     */
    function _removeERC20PaymentToken(address token) internal virtual {
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
