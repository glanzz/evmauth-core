// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909Price} from "src/ERC6909/extensions/IERC6909Price.sol";
import {ERC6909Price} from "src/ERC6909/extensions/ERC6909Price.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

contract MockERC6909Price is ERC6909Price {
    // This contract is for testing purposes only, so it performs no permission checks
    constructor(address payable treasury) ERC6909Price(treasury) {}

    function setTokenPrice(uint256 id, uint256 price) external {
        _setTokenPrice(id, price);
    }

    function suspendTokenPrice(uint256 id) external {
        _suspendTokenPrice(id);
    }

    function setTreasury(address payable treasury) external {
        _setTreasury(treasury);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }

    function testValidatePurchase(address receiver, uint256 id, uint256 amount) external view returns (uint256) {
        return _validatePurchase(receiver, id, amount);
    }

    function testCompletePurchase(address receiver, uint256 id, uint256 amount, uint256 totalPrice) external {
        _completePurchase(receiver, id, amount, totalPrice);
    }

    function testGetTreasury() external view returns (address payable) {
        return _getTreasury();
    }
}

contract ERC6909PriceTest is Test {
    MockERC6909Price public token;

    address payable public treasury = payable(address(0x123));
    address payable public newTreasury = payable(address(0x321));
    address public alice = address(0x456);
    address public bob = address(0x789);

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant PRICE_1 = 0.1 ether;
    uint256 public constant PRICE_2 = 0.2 ether;

    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);
    event ERC6909PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC6909PriceSuspended(address caller, uint256 indexed id);
    event TreasuryUpdated(address caller, address indexed account);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    function setUp() public {
        token = new MockERC6909Price(treasury);
    }

    function test_constructor() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_constructorWithZeroTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceInvalidTreasury.selector, address(0)));
        new MockERC6909Price(payable(address(0)));
    }

    function test_setTokenPrice() public {
        vm.expectEmit(true, true, true, true);
        emit ERC6909PriceUpdated(address(this), TOKEN_ID_1, PRICE_1);

        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertTrue(token.isPriceSet(TOKEN_ID_1));
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
    }

    function test_setTokenPriceToZero() public {
        token.setTokenPrice(TOKEN_ID_1, 0);

        assertTrue(token.isPriceSet(TOKEN_ID_1));
        assertEq(token.priceOf(TOKEN_ID_1), 0);
    }

    function test_suspendTokenPrice() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.isPriceSet(TOKEN_ID_1));

        // Suspend the token price
        vm.expectEmit(true, true, true, true);
        emit ERC6909PriceSuspended(address(this), TOKEN_ID_1);

        token.suspendTokenPrice(TOKEN_ID_1);
        assertFalse(token.isPriceSet(TOKEN_ID_1));

        // Confirm _validatePurchase will revert for the suspended token
        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.testValidatePurchase(alice, TOKEN_ID_1, 1);

        // Confirm suspending a non-set token price does noting
        token.suspendTokenPrice(TOKEN_ID_2);
        assertFalse(token.isPriceSet(TOKEN_ID_2));

        // Re-enable the token by setting the price again
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.isPriceSet(TOKEN_ID_1));
    }

    function test_setTreasury() public {
        vm.expectEmit(true, true, true, true);
        emit TreasuryUpdated(address(this), newTreasury);

        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
    }

    function test_setTreasuryToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceInvalidTreasury.selector, address(0)));
        token.setTreasury(payable(address(0)));
    }

    function test_isPriceSet() public {
        assertFalse(token.isPriceSet(TOKEN_ID_1));

        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertTrue(token.isPriceSet(TOKEN_ID_1));
    }

    function test_priceOf() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
    }

    function test_priceOfNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.priceOf(TOKEN_ID_1);
    }

    function test_validatePurchase() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        uint256 amount = 5;
        uint256 expectedTotalPrice = PRICE_1 * amount;

        uint256 totalPrice = token.testValidatePurchase(alice, TOKEN_ID_1, amount);

        assertEq(totalPrice, expectedTotalPrice);
    }

    function test_validatePurchaseZeroAmount() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceInvalidAmount.selector, 0));
        token.testValidatePurchase(alice, TOKEN_ID_1, 0);
    }

    function test_validatePurchaseZeroAddress() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceInvalidReceiver.selector, address(0)));
        token.testValidatePurchase(address(0), TOKEN_ID_1, 1);
    }

    function test_validatePurchasePriceNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Price.ERC6909PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.testValidatePurchase(alice, TOKEN_ID_1, 1);
    }

    function test_completePurchase() public {
        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), address(0), alice, TOKEN_ID_1, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(address(this), alice, TOKEN_ID_1, amount, totalPrice);

        token.testCompletePurchase(alice, TOKEN_ID_1, amount, totalPrice);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_getTreasury() public view {
        assertEq(token.testGetTreasury(), treasury);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909Price).interfaceId));
    }

    function test_updatePriceMultipleTimes() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);

        token.setTokenPrice(TOKEN_ID_1, PRICE_2);
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_2);

        token.setTokenPrice(TOKEN_ID_1, 0);
        assertEq(token.priceOf(TOKEN_ID_1), 0);
    }

    function test_multipleTokenPrices() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        token.setTokenPrice(TOKEN_ID_2, PRICE_2);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
        assertEq(token.priceOf(TOKEN_ID_2), PRICE_2);
    }

    function test_treasuryReceivesCorrectAddress() public {
        assertEq(token.treasury(), treasury);
        assertEq(token.testGetTreasury(), treasury);

        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
        assertEq(token.testGetTreasury(), newTreasury);
    }

    function testFuzz_setTokenPrice(uint256 id, uint256 price) public {
        token.setTokenPrice(id, price);

        assertTrue(token.isPriceSet(id));
        assertEq(token.priceOf(id), price);
    }

    function testFuzz_validatePurchase(uint256 price, uint256 amount) public {
        // Bound inputs to avoid overflow
        price = bound(price, 0, type(uint256).max / 1000);
        amount = bound(amount, 1, 1000);

        token.setTokenPrice(TOKEN_ID_1, price);

        uint256 totalPrice = token.testValidatePurchase(alice, TOKEN_ID_1, amount);

        assertEq(totalPrice, price * amount);
    }
}
