// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155AccessControlPrice} from "./ERC1155AccessControlPrice.sol";
import {IERC1155Purchase} from "./extensions/IERC1155Purchase.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Extension of ERC1155AccessControlPrice that adds native token purchase functionality.
 * This avoids diamond inheritance by extending AccessControlPrice and implementing purchase methods.
 */
abstract contract ERC1155AccessControlPurchase is ERC1155AccessControlPrice, IERC1155Purchase {
    // Errors
    error ERC1155PriceInsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);

    /**
     * @dev Sets the initial values for `defaultAdminDelay`, `defaultAdmin` address, and treasury.
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        ERC1155AccessControlPrice(initialDelay, initialDefaultAdmin, treasuryAccount, uri_)
    {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155AccessControlPrice, IERC165)
        returns (bool)
    {
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

        _mint(receiver, id, amount, "");

        if (totalPrice > 0) {
            (bool success,) = _getTreasury().call{value: totalPrice}("");
            require(success, "Transfer failed");
        }

        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess,) = msg.sender.call{value: msg.value - totalPrice}("");
            require(refundSuccess, "Refund failed");
        }

        emit Purchase(_msgSender(), receiver, id, amount, totalPrice);
    }
}
