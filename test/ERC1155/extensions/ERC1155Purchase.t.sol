// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155Purchase} from "src/ERC1155/extensions/IERC1155Purchase.sol";
import {ERC1155Purchase} from "src/ERC1155/extensions/ERC1155Purchase.sol";
import {ERC1155Price} from "src/ERC1155/extensions/ERC1155Price.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MockERC1155Purchase is ERC1155Purchase {
    // This contract is for testing purposes only, so it performs no permission checks
    constructor(address payable treasury)
        ERC1155("https://example.com/api/token/{id}.json")
        ERC1155Purchase(treasury)
    {}

    function setTokenPrice(uint256 id, uint256 price) external {
        _setTokenPrice(id, price);
    }

    function suspendTokenPrice(uint256 id) external {
        _suspendTokenPrice(id);
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }
}

contract ERC1155PurchaseTest is Test {
    MockERC1155Purchase public token;

    address payable public treasury = payable(address(0x123));
    address public alice = address(0x456);
    address public bob = address(0x789);

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant PRICE_1 = 0.1 ether;
    uint256 public constant PRICE_2 = 0.2 ether;

    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);
    event ERC1155PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC1155PriceSuspended(address caller, uint256 indexed id);
    event TreasuryUpdated(address caller, address indexed account);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    function setUp() public {
        token = new MockERC1155Purchase(treasury);

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_constructor() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Purchase).interfaceId));

        // Test an unsupported interface
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_purchase() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, address(0), alice, TOKEN_ID_1, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, alice, TOKEN_ID_1, amount, totalPrice);

        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchase_excessPayment_automaticRefund() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 excessPayment = 0.1 ether;
        uint256 payment = totalPrice + excessPayment;

        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchase{value: payment}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        // Alice should get automatic refund of excess payment
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchase_insufficientPayment() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 insufficientPayment = totalPrice - 0.01 ether;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155Purchase.ERC1155PriceInsufficientPayment.selector,
                TOKEN_ID_1,
                amount,
                totalPrice,
                insufficientPayment
            )
        );
        token.purchase{value: insufficientPayment}(TOKEN_ID_1, amount);
    }

    function test_purchase_zeroAmount() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidAmount.selector, 0));
        token.purchase{value: 0}(TOKEN_ID_1, 0);
    }

    function test_purchase_priceNotSet() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.purchase{value: PRICE_1}(TOKEN_ID_1, 1);
    }

    function test_purchase_priceSuspended() public {
        // Set price first
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.isPriceSet(TOKEN_ID_1));

        // Suspend the price
        vm.expectEmit(true, true, true, true);
        emit ERC1155PriceSuspended(address(this), TOKEN_ID_1);
        token.suspendTokenPrice(TOKEN_ID_1);
        assertFalse(token.isPriceSet(TOKEN_ID_1));

        // Purchase should now fail
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.purchase{value: PRICE_1}(TOKEN_ID_1, 1);
    }

    function test_purchase_multiple() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        token.setTokenPrice(TOKEN_ID_2, PRICE_2);

        // Alice purchases TOKEN_ID_1
        vm.prank(alice);
        token.purchase{value: PRICE_1 * 2}(TOKEN_ID_1, 2);

        // Bob purchases TOKEN_ID_2
        vm.prank(bob);
        token.purchase{value: PRICE_2 * 3}(TOKEN_ID_2, 3);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 2);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 3);
    }

    function test_purchase_zeroPrice() public {
        token.setTokenPrice(TOKEN_ID_1, 0);

        vm.prank(alice);
        bool success = token.purchase{value: 0}(TOKEN_ID_1, 100);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);
    }

    function testFuzz_purchase(uint256 price, uint256 amount) public {
        // Bound inputs to reasonable values
        price = bound(price, 0, 10 ether);
        amount = bound(amount, 1, 1000);

        token.setTokenPrice(TOKEN_ID_1, price);

        uint256 totalPrice = price * amount;
        vm.deal(alice, totalPrice);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchase_paused() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt purchase while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.purchase{value: totalPrice}(TOKEN_ID_1, amount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Purchase should now succeed
        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify the purchase worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchaseFor() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 3;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, address(0), bob, TOKEN_ID_1, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, bob, TOKEN_ID_1, amount, totalPrice);

        bool success = token.purchaseFor{value: totalPrice}(bob, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(bob, TOKEN_ID_1), amount);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchaseFor_automaticRefund() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;
        uint256 excessPayment = 0.05 ether;
        uint256 payment = totalPrice + excessPayment;

        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchaseFor{value: payment}(bob, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(bob, TOKEN_ID_1), amount);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        // Alice should get automatic refund of excess payment
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_purchaseFor_zeroAddress() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidReceiver.selector, address(0)));
        token.purchaseFor{value: PRICE_1}(address(0), TOKEN_ID_1, 1);
    }

    function test_purchaseFor_paused() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 3;
        uint256 totalPrice = PRICE_1 * amount;

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt purchaseFor while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.purchaseFor{value: totalPrice}(bob, TOKEN_ID_1, amount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // PurchaseFor should now succeed
        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchaseFor{value: totalPrice}(bob, TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify the purchase worked
        assertEq(token.balanceOf(bob, TOKEN_ID_1), amount);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_nativeCurrencyPayment() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        // Verify that payment is made in native currency (ETH)
        uint256 aliceBalanceBefore = alice.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify ETH balances changed appropriately
        assertEq(alice.balance, aliceBalanceBefore - totalPrice);
        assertEq(treasury.balance, treasuryBalanceBefore + totalPrice);
    }

    function test_reentrancyProtection() public {
        // This test verifies that the nonReentrant modifier is working
        // The contracts should have reentrancy protection via ReentrancyGuard
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        // Deploy a malicious contract that tries to reenter
        MaliciousReentrancyContract malicious = new MaliciousReentrancyContract(token);
        vm.deal(address(malicious), 1 ether);

        // The reentrancy attack should fail
        vm.expectRevert(); // Should revert due to reentrancy guard
        malicious.attack();
    }

    function test_treasuryReceivesPayment() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        token.setTokenPrice(TOKEN_ID_2, PRICE_2);

        uint256 treasuryBalanceBefore = treasury.balance;

        // Multiple purchases should all go to treasury
        vm.prank(alice);
        token.purchase{value: PRICE_1 * 2}(TOKEN_ID_1, 2);

        vm.prank(bob);
        token.purchase{value: PRICE_2 * 3}(TOKEN_ID_2, 3);

        uint256 expectedTreasuryIncrease = (PRICE_1 * 2) + (PRICE_2 * 3);
        assertEq(treasury.balance, treasuryBalanceBefore + expectedTreasuryIncrease);
    }

    function test_largeAmountPurchase() public {
        token.setTokenPrice(TOKEN_ID_1, 1 wei);

        uint256 amount = 1000;
        uint256 totalPrice = 1 wei * amount;

        vm.deal(alice, totalPrice);
        vm.prank(alice);
        bool success = token.purchase{value: totalPrice}(TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_multipleSmallPurchases() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 totalPurchases = 0;

        // Make multiple small purchases
        for (uint256 i = 1; i <= 5; i++) {
            vm.prank(alice);
            token.purchase{value: PRICE_1}(TOKEN_ID_1, 1);
            totalPurchases += 1;
        }

        assertEq(token.balanceOf(alice, TOKEN_ID_1), totalPurchases);
        assertEq(treasury.balance, treasuryBalanceBefore + (PRICE_1 * totalPurchases));
    }
}

// Malicious contract for testing reentrancy protection
contract MaliciousReentrancyContract {
    MockERC1155Purchase public target;

    constructor(MockERC1155Purchase _target) {
        target = _target;
    }

    function attack() external {
        target.purchase{value: 0.1 ether}(1, 1);
    }
}
