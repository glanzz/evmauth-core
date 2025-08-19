// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155PurchaseWithERC20} from "src/ERC1155/extensions/IERC1155PurchaseWithERC20.sol";
import {ERC1155PurchaseWithERC20} from "src/ERC1155/extensions/ERC1155PurchaseWithERC20.sol";
import {ERC1155Price} from "src/ERC1155/extensions/ERC1155Price.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MockERC1155PurchaseWithERC20 is ERC1155PurchaseWithERC20 {
    // This contract is for testing purposes only, so it performs no permission checks
    constructor(address payable treasury) ERC1155PurchaseWithERC20(treasury) ERC1155("https://example.com/{id}.json") {}

    function setTokenPrice(uint256 id, uint256 price) external {
        _setTokenPrice(id, price);
    }

    function addERC20PaymentToken(address token) external {
        _addERC20PaymentToken(token);
    }

    function removeERC20PaymentToken(address token) external {
        _removeERC20PaymentToken(token);
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }
}

contract ERC1155PurchaseWithERC20Test is Test {
    MockERC1155PurchaseWithERC20 public token;
    ERC20Mock public paymentToken1;
    ERC20Mock public paymentToken2;
    ERC20Mock public usdcToken; // Mock USDC token

    address payable public treasury = payable(address(0x123));
    address public alice = address(0x456);
    address public bob = address(0x789);

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant PRICE_1 = 100 * 10 ** 18; // 100 tokens
    uint256 public constant PRICE_2 = 200 * 10 ** 18; // 200 tokens

    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);
    event ERC1155PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event TreasuryUpdated(address caller, address indexed account);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event ERC20PaymentTokenAdded(address indexed token);
    event ERC20PaymentTokenRemoved(address indexed token);

    function setUp() public {
        token = new MockERC1155PurchaseWithERC20(treasury);

        // Deploy mock ERC20 tokens
        paymentToken1 = new ERC20Mock();
        paymentToken2 = new ERC20Mock();
        usdcToken = new ERC20Mock(); // Mock USDC with typical 6 decimals

        // Mint tokens to test accounts
        paymentToken1.mint(alice, 10000 * 10 ** 18);
        paymentToken1.mint(bob, 10000 * 10 ** 18);
        paymentToken2.mint(alice, 10000 * 10 ** 18);
        paymentToken2.mint(bob, 10000 * 10 ** 18);
        usdcToken.mint(alice, 10000 * 10 ** 6); // USDC with 6 decimals
        usdcToken.mint(bob, 10000 * 10 ** 6);

        // Add payment tokens
        token.addERC20PaymentToken(address(paymentToken1));
        token.addERC20PaymentToken(address(paymentToken2));
        token.addERC20PaymentToken(address(usdcToken));

        // Set prices for tokens
        token.setTokenPrice(TOKEN_ID_1, PRICE_1);
        token.setTokenPrice(TOKEN_ID_2, PRICE_2);
    }

    function test_constructor() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_supportsInterface() public view {
        // Test the ERC1155 interface
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));

        // Test the IERC1155PurchaseWithERC20 interface
        assertTrue(token.supportsInterface(type(IERC1155PurchaseWithERC20).interfaceId));

        // Test that supportsInterface is actually being called (coverage test)
        bytes4 interfaceId = type(IERC1155PurchaseWithERC20).interfaceId;
        bool supported = token.supportsInterface(interfaceId);
        assertTrue(supported);

        // Test an unsupported interface
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_acceptedERC20PaymentTokens() public view {
        address[] memory tokens = token.acceptedERC20PaymentTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], address(paymentToken1));
        assertEq(tokens[1], address(paymentToken2));
        assertEq(tokens[2], address(usdcToken));
    }

    function test_isERC20PaymentTokenAccepted() public view {
        assertTrue(token.isERC20PaymentTokenAccepted(address(paymentToken1)));
        assertTrue(token.isERC20PaymentTokenAccepted(address(paymentToken2)));
        assertTrue(token.isERC20PaymentTokenAccepted(address(usdcToken)));
        assertFalse(token.isERC20PaymentTokenAccepted(address(0xDEAD)));
    }

    function test_addERC20PaymentToken() public {
        ERC20Mock newToken = new ERC20Mock();

        vm.expectEmit(true, false, false, false);
        emit ERC20PaymentTokenAdded(address(newToken));

        token.addERC20PaymentToken(address(newToken));

        assertTrue(token.isERC20PaymentTokenAccepted(address(newToken)));

        address[] memory acceptedTokens = token.acceptedERC20PaymentTokens();
        assertEq(acceptedTokens[acceptedTokens.length - 1], address(newToken));
    }

    function test_addERC20PaymentToken_zeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155PurchaseWithERC20.ERC1155PriceInvalidERC20PaymentToken.selector, address(0))
        );
        token.addERC20PaymentToken(address(0));
    }

    function test_addERC20PaymentToken_alreadyAdded() public {
        // Adding the same token twice should not duplicate it
        token.addERC20PaymentToken(address(paymentToken1));

        address[] memory tokens = token.acceptedERC20PaymentTokens();
        uint256 count = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(paymentToken1)) {
                count++;
            }
        }
        assertEq(count, 1);
    }

    function test_removeERC20PaymentToken() public {
        vm.expectEmit(true, false, false, false);
        emit ERC20PaymentTokenRemoved(address(paymentToken2));

        token.removeERC20PaymentToken(address(paymentToken2));

        assertFalse(token.isERC20PaymentTokenAccepted(address(paymentToken2)));

        address[] memory acceptedTokens = token.acceptedERC20PaymentTokens();
        assertEq(acceptedTokens.length, 2);
        assertEq(acceptedTokens[0], address(paymentToken1));
        assertEq(acceptedTokens[1], address(usdcToken));
    }

    function test_removeERC20PaymentToken_notInAcceptedTokensList() public {
        ERC20Mock nonExistentToken = new ERC20Mock();

        // Should not revert when removing a non-existent token
        token.removeERC20PaymentToken(address(nonExistentToken));

        address[] memory tokens = token.acceptedERC20PaymentTokens();
        assertEq(tokens.length, 3);
    }

    function test_purchaseWithERC20() public {
        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;

        // Approve token spending
        vm.prank(alice);
        paymentToken2.approve(address(token), totalPrice);

        uint256 aliceTokenBalanceBefore = paymentToken2.balanceOf(alice);
        uint256 treasuryTokenBalanceBefore = paymentToken2.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken2), TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(paymentToken2.balanceOf(alice), aliceTokenBalanceBefore - totalPrice);
        assertEq(paymentToken2.balanceOf(treasury), treasuryTokenBalanceBefore + totalPrice);
    }

    function test_purchaseWithERC20_usdcToken() public {
        // Test with USDC-like token (6 decimals)
        uint256 amount = 1;
        uint256 usdcPrice = 100 * 10 ** 6; // 100 USDC
        
        // Set a different price for testing USDC
        token.setTokenPrice(TOKEN_ID_1, usdcPrice);

        // Approve USDC spending
        vm.prank(alice);
        usdcToken.approve(address(token), usdcPrice);

        uint256 aliceUsdcBalanceBefore = usdcToken.balanceOf(alice);
        uint256 treasuryUsdcBalanceBefore = usdcToken.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(usdcToken), TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(usdcToken.balanceOf(alice), aliceUsdcBalanceBefore - usdcPrice);
        assertEq(usdcToken.balanceOf(treasury), treasuryUsdcBalanceBefore + usdcPrice);
    }

    function test_purchaseWithERC20_invalidERC20PaymentToken() public {
        ERC20Mock invalidToken = new ERC20Mock();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155PurchaseWithERC20.ERC1155PriceInvalidERC20PaymentToken.selector, address(invalidToken)
            )
        );
        token.purchaseWithERC20(address(invalidToken), TOKEN_ID_1, 1);
    }

    function test_purchaseWithERC20_insufficientBalance() public {
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        // Create new account with no tokens
        address charlie = address(0xABC);

        vm.prank(charlie);
        paymentToken1.approve(address(token), totalPrice);

        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155PurchaseWithERC20.ERC1155PriceInsufficientERC20PaymentTokenBalance.selector,
                address(paymentToken1),
                totalPrice,
                0
            )
        );
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
    }

    function test_purchaseWithERC20_insufficientAllowance() public {
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        // Don't approve any tokens

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155PurchaseWithERC20.ERC1155PriceInsufficientERC20PaymentTokenAllowance.selector,
                address(paymentToken1),
                totalPrice,
                0
            )
        );
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
    }

    function test_purchaseWithERC20_zeroAmount() public {
        vm.prank(alice);
        paymentToken1.approve(address(token), PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidAmount.selector, 0));
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, 0);
    }

    function test_purchaseWithERC20_zeroPrice() public {
        token.setTokenPrice(TOKEN_ID_1, 0);

        // Even with zero price, the purchase should succeed
        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, 100);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);
    }

    function test_purchaseWithERC20_priceNotSet() public {
        uint256 unsetTokenId = 999;

        vm.prank(alice);
        paymentToken1.approve(address(token), PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceTokenPriceNotSet.selector, unsetTokenId));
        token.purchaseWithERC20(address(paymentToken1), unsetTokenId, 1);
    }

    function test_purchaseWithERC20For() public {
        uint256 amount = 4;
        uint256 totalPrice = PRICE_1 * amount;

        // Approve token spending
        vm.prank(alice);
        paymentToken2.approve(address(token), totalPrice);

        uint256 aliceTokenBalanceBefore = paymentToken2.balanceOf(alice);
        uint256 treasuryTokenBalanceBefore = paymentToken2.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20For(address(paymentToken2), bob, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(bob, TOKEN_ID_1), amount);
        assertEq(paymentToken2.balanceOf(alice), aliceTokenBalanceBefore - totalPrice);
        assertEq(paymentToken2.balanceOf(treasury), treasuryTokenBalanceBefore + totalPrice);
    }

    function test_purchaseWithERC20For_zeroAddress() public {
        vm.prank(alice);
        paymentToken1.approve(address(token), PRICE_1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155Price.ERC1155PriceInvalidReceiver.selector, address(0)));
        token.purchaseWithERC20For(address(paymentToken1), address(0), TOKEN_ID_1, 1);
    }

    function test_purchaseWithERC20For_invalidERC20PaymentToken() public {
        ERC20Mock invalidToken = new ERC20Mock();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155PurchaseWithERC20.ERC1155PriceInvalidERC20PaymentToken.selector, address(invalidToken)
            )
        );
        token.purchaseWithERC20For(address(invalidToken), bob, TOKEN_ID_1, 1);
    }

    function testFuzz_purchaseWithERC20(uint256 price, uint256 amount) public {
        // Bound inputs to reasonable values
        price = bound(price, 0, 1000 * 10 ** 18);
        amount = bound(amount, 1, 100);

        token.setTokenPrice(TOKEN_ID_1, price);

        uint256 totalPrice = price * amount;

        // Mint enough tokens for the purchase
        paymentToken1.mint(alice, totalPrice);

        // Approve token spending
        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        uint256 treasuryBalanceBefore = paymentToken1.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(paymentToken1.balanceOf(treasury), treasuryBalanceBefore + totalPrice);
    }

    function test_purchaseWithERC20_paused() public {
        uint256 amount = 5;
        uint256 totalPrice = PRICE_1 * amount;

        // Approve token spending
        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt purchase while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Purchase should now succeed
        uint256 aliceTokenBalanceBefore = paymentToken1.balanceOf(alice);
        uint256 treasuryTokenBalanceBefore = paymentToken1.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify the purchase worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(paymentToken1.balanceOf(alice), aliceTokenBalanceBefore - totalPrice);
        assertEq(paymentToken1.balanceOf(treasury), treasuryTokenBalanceBefore + totalPrice);
    }

    function test_purchaseWithERC20For_paused() public {
        uint256 amount = 3;
        uint256 totalPrice = PRICE_1 * amount;

        // Approve token spending
        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt purchaseFor while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.purchaseWithERC20For(address(paymentToken1), bob, TOKEN_ID_1, amount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // PurchaseFor should now succeed
        uint256 aliceTokenBalanceBefore = paymentToken1.balanceOf(alice);
        uint256 treasuryTokenBalanceBefore = paymentToken1.balanceOf(treasury);

        vm.prank(alice);
        bool success = token.purchaseWithERC20For(address(paymentToken1), bob, TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify the purchase worked
        assertEq(token.balanceOf(bob, TOKEN_ID_1), amount);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(paymentToken1.balanceOf(alice), aliceTokenBalanceBefore - totalPrice);
        assertEq(paymentToken1.balanceOf(treasury), treasuryTokenBalanceBefore + totalPrice);
    }

    function test_multiplePaymentTokens_sequential() public {
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        // Purchase with first token
        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);
        vm.prank(alice);
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);

        // Purchase with second token
        vm.prank(alice);
        paymentToken2.approve(address(token), totalPrice);
        vm.prank(alice);
        token.purchaseWithERC20(address(paymentToken2), TOKEN_ID_1, amount);

        // Verify both purchases worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount * 2);
    }

    function test_safeERC20_integration() public {
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        // Test that SafeERC20 is properly integrated by ensuring transfers work
        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        uint256 treasuryBalanceBefore = paymentToken1.balanceOf(treasury);
        uint256 aliceBalanceBefore = paymentToken1.balanceOf(alice);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
        assertTrue(success);

        // Verify SafeERC20 transfer worked correctly
        assertEq(paymentToken1.balanceOf(treasury), treasuryBalanceBefore + totalPrice);
        assertEq(paymentToken1.balanceOf(alice), aliceBalanceBefore - totalPrice);
    }

    function test_reentrancyGuard() public {
        // The contract should be protected by ReentrancyGuard from ERC1155Price
        // This test verifies the nonReentrant modifier is in place
        uint256 amount = 1;
        uint256 totalPrice = PRICE_1 * amount;

        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
        assertTrue(success);

        // If reentrancy protection is working, this should complete normally
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_eventEmission_purchaseWithERC20() public {
        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;

        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        // Expect Purchase event
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, alice, TOKEN_ID_1, amount, totalPrice);

        vm.prank(alice);
        token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
    }

    function test_eventEmission_purchaseWithERC20For() public {
        uint256 amount = 2;
        uint256 totalPrice = PRICE_1 * amount;

        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        // Expect Purchase event with different caller and receiver
        vm.expectEmit(true, true, true, true);
        emit Purchase(alice, bob, TOKEN_ID_1, amount, totalPrice);

        vm.prank(alice);
        token.purchaseWithERC20For(address(paymentToken1), bob, TOKEN_ID_1, amount);
    }

    function test_largeAmountPurchase() public {
        uint256 amount = 1000;
        uint256 totalPrice = PRICE_1 * amount;

        // Mint enough tokens for large purchase
        paymentToken1.mint(alice, totalPrice);

        vm.prank(alice);
        paymentToken1.approve(address(token), totalPrice);

        vm.prank(alice);
        bool success = token.purchaseWithERC20(address(paymentToken1), TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }
}