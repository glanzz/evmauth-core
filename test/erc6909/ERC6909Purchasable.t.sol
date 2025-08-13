// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909Purchasable} from "../../src/erc6909/IERC6909Purchasable.sol";
import {ERC6909Purchasable} from "../../src/erc6909/ERC6909Purchasable.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";

contract MockERC6909Purchasable is ERC6909Purchasable {
    // This contract is for testing purposes only, so it performs no permission checks

    constructor(address payable treasury) ERC6909Purchasable(treasury) {}

    function setPrice(uint256 id, uint256 price) external {
        _setPrice(id, price);
    }

    function setTreasury(address payable treasury) external {
        _setTreasury(treasury);
    }
}

contract ERC6909PurchasableTest is Test {
    MockERC6909Purchasable public token;

    address payable public treasury;
    address public alice;
    address public bob;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TOKEN_ID_3 = 3;

    uint256 public constant PRICE_1 = 0.1 ether;
    uint256 public constant PRICE_2 = 0.5 ether;
    uint256 public constant PRICE_3 = 1 ether;

    // ERC6909 Events
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed spender, bool approved);
    event Transfer(
        address caller, address indexed sender, address indexed receiver, uint256 indexed id, uint256 amount
    );

    // ERC6909Purchasable Events
    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);
    event TokenPriceSet(address caller, uint256 indexed id, uint256 price);
    event TreasurySet(address caller, address indexed account);

    function setUp() public {
        treasury = payable(makeAddr("treasury"));
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        token = new MockERC6909Purchasable(treasury);
    }

    function test_setPrice() public {
        vm.expectEmit(true, true, false, true);
        emit TokenPriceSet(address(this), TOKEN_ID_1, PRICE_1);

        token.setPrice(TOKEN_ID_1, PRICE_1);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
    }

    function test_setMultiplePrices() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);
        token.setPrice(TOKEN_ID_2, PRICE_2);
        token.setPrice(TOKEN_ID_3, PRICE_3);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
        assertEq(token.priceOf(TOKEN_ID_2), PRICE_2);
        assertEq(token.priceOf(TOKEN_ID_3), PRICE_3);
    }

    function test_setTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectEmit(true, true, false, true);
        emit TreasurySet(address(this), newTreasury);

        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
    }

    function test_setTreasury_zeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Purchasable.ERC6909PurchasableInvalidTreasury.selector, address(0))
        );
        token.setTreasury(payable(address(0)));
    }

    function test_purchase() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), alice, TOKEN_ID_1, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, alice, TOKEN_ID_1, amount, totalPrice);

        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchaseFor() public {
        token.setPrice(TOKEN_ID_2, PRICE_2);

        uint256 amount = 3;
        uint256 totalPrice = PRICE_2 * amount;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), bob, TOKEN_ID_2, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, bob, TOKEN_ID_2, amount, totalPrice);

        bool success = token.purchaseFor{value: totalPrice}(bob, TOKEN_ID_2, amount);
        assertTrue(success);

        assertEq(token.balanceOf(bob, TOKEN_ID_2), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchase_withExcessPayment() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 excess = 0.1 ether;
        uint256 payment = totalPrice + excess;

        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchase{value: payment}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
        assertEq(alice.balance, aliceBalanceBefore - totalPrice); // Excess was refunded
    }

    function test_purchase_insufficientPayment() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 insufficientPayment = totalPrice - 0.01 ether;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909Purchasable.ERC6909PurchasableInsufficientPayment.selector,
                TOKEN_ID_1,
                amount,
                totalPrice,
                insufficientPayment
            )
        );
        token.purchase{value: insufficientPayment}(TOKEN_ID_1, amount);
    }

    function test_purchase_zeroAmount() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909Purchasable.ERC6909PurchasableInvalidAmount.selector, 0));
        token.purchase{value: 0}(TOKEN_ID_1, 0);
    }

    function test_purchase_invalidReceiver() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Purchasable.ERC6909PurchasableInvalidReceiver.selector, address(0))
        );
        token.purchaseFor{value: totalPrice}(address(0), TOKEN_ID_1, amount);
    }

    function test_purchase_zeroPrice() public {
        // Don't set price (defaults to 0)
        uint256 amount = 100;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Purchasable.ERC6909PurchasableInvalidPrice.selector, TOKEN_ID_1, 0)
        );
        token.purchase{value: 0}(TOKEN_ID_1, amount);
    }

    function test_purchase_multipleTokenTypes() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);
        token.setPrice(TOKEN_ID_2, PRICE_2);

        uint256 treasuryBalanceBefore = treasury.balance;

        // Purchase TOKEN_ID_1
        vm.prank(alice);
        token.purchase{value: PRICE_1 * 2}(TOKEN_ID_1, 2);

        // Purchase TOKEN_ID_2
        vm.prank(bob);
        token.purchaseFor{value: PRICE_2 * 3}(alice, TOKEN_ID_2, 3);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 2);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 3);
        assertEq(treasury.balance, treasuryBalanceBefore + (PRICE_1 * 2) + (PRICE_2 * 3));
    }

    function test_updatePrice() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);

        // Update price
        token.setPrice(TOKEN_ID_1, PRICE_2);
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_2);

        // Purchase with new price
        vm.prank(alice);
        token.purchase{value: PRICE_2}(TOKEN_ID_1, 1);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1);
    }

    function test_updateTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        token.setTreasury(newTreasury);
        assertEq(token.treasury(), newTreasury);

        // Purchase should go to new treasury
        token.setPrice(TOKEN_ID_1, PRICE_1);
        uint256 newTreasuryBalanceBefore = newTreasury.balance;

        vm.prank(alice);
        token.purchase{value: PRICE_1}(TOKEN_ID_1, 1);

        assertEq(newTreasury.balance, newTreasuryBalanceBefore + PRICE_1);
    }

    function test_purchase_largeAmount() public {
        token.setPrice(TOKEN_ID_1, 0.001 ether);

        uint256 amount = 1000;
        uint256 totalPrice = 0.001 ether * amount;

        vm.prank(alice);
        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909Purchasable).interfaceId));
    }

    function test_tokenTransferAfterPurchase() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        // Alice purchases tokens
        vm.prank(alice);
        token.purchase{value: PRICE_1 * 5}(TOKEN_ID_1, 5);

        // Alice transfers to Bob
        vm.prank(alice);
        bool success = token.transfer(bob, TOKEN_ID_1, 3);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 2);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 3);
    }

    function test_approveAndTransferFromAfterPurchase() public {
        token.setPrice(TOKEN_ID_1, PRICE_1);

        // Alice purchases tokens
        vm.prank(alice);
        token.purchase{value: PRICE_1 * 10}(TOKEN_ID_1, 10);

        // Alice approves Bob
        vm.prank(alice);
        token.approve(bob, TOKEN_ID_1, 5);

        // Bob transfers from Alice
        vm.prank(bob);
        bool success = token.transferFrom(alice, bob, TOKEN_ID_1, 3);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 7);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 3);
        assertEq(token.allowance(alice, bob, TOKEN_ID_1), 2);
    }

    function test_purchaseFor_zeroPrice() public {
        // Don't set price (defaults to 0)
        uint256 amount = 50;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Purchasable.ERC6909PurchasableInvalidPrice.selector, TOKEN_ID_1, 0)
        );
        token.purchaseFor{value: 0}(bob, TOKEN_ID_1, amount);
    }
}
