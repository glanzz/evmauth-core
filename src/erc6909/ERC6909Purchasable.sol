// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC6909Purchasable} from "./IERC6909Purchasable.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract that supports the direct purchase of tokens.
 */
contract ERC6909Purchasable is ReentrancyGuard, ERC6909, IERC6909Purchasable {
    // Token ID => price mapping
    mapping(uint256 => uint256) private _prices;

    // Wallet address where token purchase revenues will be sent
    address payable private _treasury;

    error ERC6909PurchasableInsufficientPayment(uint256 id, uint256 amount, uint256 price, uint256 paid);
    error ERC6909PurchasableInvalidAmount(uint256 amount);
    error ERC6909PurchasableInvalidPrice(uint256 id, uint256 price);
    error ERC6909PurchasableInvalidReceiver(address receiver);
    error ERC6909PurchasableInvalidTreasury(address treasury);

    /**
     * @dev Sets the initial `_treasury` address that will receive token purchase revenues.
     *
     * Emits a {TreasurySet} event.
     *
     * Revert if `treasuryAccount` is the zero address.
     */
    constructor(address payable treasuryAccount) {
        _setTreasury(treasuryAccount);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, IERC165) returns (bool) {
        return interfaceId == type(IERC6909Purchasable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909Purchasable
    function priceOf(uint256 id) external view returns (uint256) {
        return _prices[id];
    }

    /// @inheritdoc IERC6909Purchasable
    function treasury() external virtual returns (address) {
        return _treasury;
    }

    /// @inheritdoc IERC6909Purchasable
    function purchase(uint256 id, uint256 amount) external payable virtual nonReentrant returns (bool) {
        _purchase(_msgSender(), id, amount);
        return true;
    }

    /// @inheritdoc IERC6909Purchasable
    function purchaseFor(address receiver, uint256 id, uint256 amount)
        external
        payable
        virtual
        nonReentrant
        returns (bool)
    {
        _purchase(receiver, id, amount);
        return true;
    }

    /**
     * @dev Internal function to handle the purchase logic.
     * It checks the treasury address, receiver address, and amount validity.
     * It calculates the total price and checks if the payment is sufficient.
     * If valid, it transfers the payment to the treasury and mints the tokens to the receiver.
     *
     * Emits a {Transfer} event with `from` set to the zero address and `to` set to the receiver's address.
     * Emits a {Purchase} event where the `caller` may be different than the `receiver`.
     *
     * Requirements:
     * - The receiver address must not be zero.
     * - The amount must be greater than zero.
     * - The token `id` must have a set price (not zero).
     * - The payment must be sufficient to cover the total price for the `amount` of tokens.
     */
    function _purchase(address receiver, uint256 id, uint256 amount) internal virtual {
        if (receiver == address(0)) {
            revert ERC6909PurchasableInvalidReceiver(receiver);
        }
        if (amount == 0) {
            revert ERC6909PurchasableInvalidAmount(amount);
        }
        if (_prices[id] == 0) {
            revert ERC6909PurchasableInvalidPrice(id, 0);
        }

        uint256 totalPrice = _prices[id] * amount;
        if (msg.value < totalPrice) {
            revert ERC6909PurchasableInsufficientPayment(id, amount, totalPrice, msg.value);
        }

        // Refund excess payment to the sender
        if (msg.value > totalPrice) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        }

        _treasury.transfer(totalPrice);

        // Mint the tokens to the receiver
        super._mint(receiver, id, amount);

        emit Purchase(_msgSender(), receiver, id, amount, totalPrice);
    }

    /**
     * @dev Sets the native currency `price` for a specific token `id`.
     */
    function _setPrice(uint256 id, uint256 price) internal {
        _prices[id] = price;

        emit TokenPriceSet(_msgSender(), id, price);
    }

    /**
     * @dev Sets the treasury address where purchase revenues will be sent.
     *
     * If you want to keep the treasury address private or implement custom logic,
     * you can override this function and the `treasury` function.
     */
    function _setTreasury(address payable treasuryAccount) internal virtual {
        if (treasuryAccount == address(0)) {
            revert ERC6909PurchasableInvalidTreasury(treasuryAccount);
        }

        _treasury = treasuryAccount;

        emit TreasurySet(_msgSender(), treasuryAccount);
    }
}
