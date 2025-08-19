// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155Price} from "./ERC1155Price.sol";
import {IERC1155Purchase} from "./IERC1155Purchase.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-1155 compliant contract that supports the direct purchase of tokens
 * using native currency (i.e. ETH).
 */
abstract contract ERC1155Purchase is ERC1155Price, IERC1155Purchase, Pausable {
    // Errors
    error ERC1155PriceInsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);

    /**
     * @dev Sets the initial `_treasury` address that will receive token purchase revenues.
     *
     * @param treasuryAccount The address where purchase revenues will be sent
     */
    constructor(address payable treasuryAccount) ERC1155Price(treasuryAccount) {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Price, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Purchase).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1155Purchase
    function purchase(uint256 id, uint256 amount)
        external
        payable
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseFor(_msgSender(), id, amount);
        return true;
    }

    /// @inheritdoc IERC1155Purchase
    function purchaseFor(address receiver, uint256 id, uint256 amount)
        external
        payable
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _purchaseFor(receiver, id, amount);
        return true;
    }

    /**
     * @dev Internal function to handle the purchase logic with native currency.
     * It validates the purchase, checks payment sufficiency, transfers funds to treasury,
     * and mints the tokens to the receiver.
     *
     * Emits a {TransferSingle} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price.
     * - The payment must be sufficient to cover the total price for the `amount` of tokens.
     *
     * @param receiver The address of the receiver who will receive the purchased tokens.
     * @param id The identifier of the token type to purchase.
     * @param amount The number of tokens to purchase.
     */
    function _purchaseFor(address receiver, uint256 id, uint256 amount) internal virtual {
        uint256 totalPrice = _validatePurchase(receiver, id, amount);

        if (msg.value < totalPrice) {
            revert ERC1155PriceInsufficientPayment(id, amount, totalPrice, msg.value);
        }

        // Refund excess payment to the sender
        if (msg.value > totalPrice) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        }

        // Transfer payment to treasury
        _getTreasury().transfer(totalPrice);

        // Complete the purchase
        _completePurchase(receiver, id, amount, totalPrice);
    }
}