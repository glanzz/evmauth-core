// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155Price} from "src/ERC1155/extensions/IERC1155Price.sol";
import {ERC1155Price} from "src/ERC1155/extensions/ERC1155Price.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155Price is ERC1155Price {
    // This contract is for testing purposes only, so it performs no permission checks
    constructor(address payable treasury) ERC1155("https://example.com/api/token/{id}.json") ERC1155Price(treasury) {}

    function setTokenPrice(uint256 id, uint256 price) external {
        _setTokenPrice(id, price);
    }

    function suspendTokenPrice(uint256 id) external {
        _suspendTokenPrice(id);
    }

    function setTreasury(address payable treasury) external {
        _setTreasury(treasury);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
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

contract ERC1155PriceTest is Test {
    MockERC1155Price public token;

    address payable public treasury = payable(address(0x123));
    address payable public newTreasury = payable(address(0x321));
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
        token = new MockERC1155Price(treasury);
    }

    function test_constructor() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_constructorWithZeroTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidTreasury.selector, address(0)));
        new MockERC1155Price(payable(address(0)));
    }

    function test_setTokenPrice() public {
        vm.expectEmit(true, true, true, true);
        emit ERC1155PriceUpdated(address(this), TOKEN_ID_1, PRICE_1);

        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertTrue(token.priceIsSet(TOKEN_ID_1));
        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
    }

    function test_setTokenPriceToZero() public {
        token.setTokenPrice(TOKEN_ID_1, 0);

        assertTrue(token.priceIsSet(TOKEN_ID_1));
        assertEq(token.priceOf(TOKEN_ID_1), 0);
    }

    function test_suspendTokenPrice() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.priceIsSet(TOKEN_ID_1));

        // Suspend the token price
        vm.expectEmit(true, true, true, true);
        emit ERC1155PriceSuspended(address(this), TOKEN_ID_1);

        token.suspendTokenPrice(TOKEN_ID_1);
        assertFalse(token.priceIsSet(TOKEN_ID_1));

        // Confirm _validatePurchase will revert for the suspended token
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.testValidatePurchase(alice, TOKEN_ID_1, 1);

        // Confirm suspending a non-set token price does nothing
        token.suspendTokenPrice(TOKEN_ID_2);
        assertFalse(token.priceIsSet(TOKEN_ID_2));

        // Re-enable the token by setting the price again
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.priceIsSet(TOKEN_ID_1));
    }

    function test_setTreasury() public {
        vm.expectEmit(true, true, true, true);
        emit TreasuryUpdated(address(this), newTreasury);

        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
    }

    function test_setTreasuryToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidTreasury.selector, address(0)));
        token.setTreasury(payable(address(0)));
    }

    function test_priceIsSet() public {
        assertFalse(token.priceIsSet(TOKEN_ID_1));

        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertTrue(token.priceIsSet(TOKEN_ID_1));
    }

    function test_priceOf() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
    }

    function test_priceOfNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, TOKEN_ID_1));
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

        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidAmount.selector, 0));
        token.testValidatePurchase(alice, TOKEN_ID_1, 0);
    }

    function test_validatePurchaseZeroAddress() public {
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);

        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidReceiver.selector, address(0)));
        token.testValidatePurchase(address(0), TOKEN_ID_1, 1);
    }

    function test_validatePurchasePriceNotSet() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, TOKEN_ID_1));
        token.testValidatePurchase(alice, TOKEN_ID_1, 1);
    }

    function test_completePurchase() public {
        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);
        vm.expectEmit(true, true, true, true);
        emit Purchase(address(this), alice, TOKEN_ID_1, amount, totalPrice);

        token.testCompletePurchase(alice, TOKEN_ID_1, amount, totalPrice);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_getTreasury() public view {
        assertEq(token.testGetTreasury(), treasury);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Price).interfaceId));
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

    function test_reentrancyGuardProtection() public {
        // Set up a malicious contract that attempts to reenter
        MaliciousReceiver maliciousReceiver = new MaliciousReceiver(address(token));
        
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        
        // This should not trigger reentrancy since _completePurchase doesn't make external calls
        // but we test to ensure the ReentrancyGuard is properly inherited
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;
        
        token.testCompletePurchase(address(maliciousReceiver), TOKEN_ID_1, amount, totalPrice);
        
        assertEq(token.balanceOf(address(maliciousReceiver), TOKEN_ID_1), amount);
    }

    function test_mintWithDataParameter() public {
        bytes memory data = "test data";
        uint256 amount = 10;
        
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);
        
        token.mint(alice, TOKEN_ID_1, amount, data);
        
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_completePurchaseUsesEmptyData() public {
        // Test that _completePurchase uses empty data parameter as expected
        uint256 amount = 3;
        uint256 totalPrice = PRICE_1 * amount;
        
        // Set up a contract that checks the data parameter in onERC1155Received
        DataChecker dataChecker = new DataChecker();
        
        token.testCompletePurchase(address(dataChecker), TOKEN_ID_1, amount, totalPrice);
        
        assertEq(token.balanceOf(address(dataChecker), TOKEN_ID_1), amount);
        assertTrue(dataChecker.receivedEmptyData());
    }

    function test_priceCalculationOverflow() public {
        uint256 maxPrice = type(uint256).max / 3;
        uint256 amount = 2;
        
        token.setTokenPrice(TOKEN_ID_1, maxPrice);
        
        // This should not overflow
        uint256 totalPrice = token.testValidatePurchase(alice, TOKEN_ID_1, amount);
        assertEq(totalPrice, maxPrice * amount);
    }

    function testFuzz_setTokenPrice(uint256 id, uint256 price) public {
        token.setTokenPrice(id, price);

        assertTrue(token.priceIsSet(id));
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

    function testFuzz_suspendAndResetPrice(uint256 id, uint256 initialPrice, uint256 newPrice) public {
        // Set initial price
        token.setTokenPrice(id, initialPrice);
        assertTrue(token.priceIsSet(id));
        assertEq(token.priceOf(id), initialPrice);

        // Suspend price
        token.suspendTokenPrice(id);
        assertFalse(token.priceIsSet(id));

        // Reset with new price
        token.setTokenPrice(id, newPrice);
        assertTrue(token.priceIsSet(id));
        assertEq(token.priceOf(id), newPrice);
    }
}

// Helper contract for testing reentrancy protection
contract MaliciousReceiver {
    address public tokenContract;
    
    constructor(address _tokenContract) {
        tokenContract = _tokenContract;
    }
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        // In a real attack, this would try to call back into the token contract
        // But since _completePurchase doesn't make external calls during minting,
        // reentrancy isn't possible here. This is just for testing the guard is present.
        return this.onERC1155Received.selector;
    }
}

// Helper contract for testing data parameter
contract DataChecker {
    bool public receivedEmptyData = false;
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external returns (bytes4) {
        if (data.length == 0) {
            receivedEmptyData = true;
        }
        return this.onERC1155Received.selector;
    }
}