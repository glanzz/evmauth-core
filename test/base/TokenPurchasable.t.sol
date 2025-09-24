// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { BaseTestWithERC20s } from "test/_helpers/BaseTest.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract MockTokenPurchasableV1 is TokenPurchasable, OwnableUpgradeable, UUPSUpgradeable {
    // For testing only; in a real implementation, use a token standard like ERC-1155 or ERC-6909.
    mapping(address => mapping(uint256 => uint256)) public balances;

    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function initialize(address initialOwner, address payable initialTreasury) public initializer {
        __MockTokenPurchasableV1_init(initialOwner, initialTreasury);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     * @param initialTreasury The address where purchase revenues will be sent.
     */
    function __MockTokenPurchasableV1_init(address initialOwner, address payable initialTreasury)
        internal
        onlyInitializing
    {
        __TokenPurchasable_init(initialTreasury);
        __Ownable_init(initialOwner);
        __MockTokenPurchasableV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockTokenPurchasableV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not authorized.
    }

    /// @inheritdoc TokenPurchasable
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        balances[to][id] += amount;
    }

    // ========== Helper Functions for Testing ==========

    function isAcceptedERC20PaymentToken(uint256 id, address token) public view returns (bool) {
        TokenPurchasable.PaymentToken[] memory prices = tokenERC20Prices(id);
        for (uint256 i = 0; i < prices.length; i++) {
            if (prices[i].token == token && prices[i].price > 0) {
                return true;
            }
        }
        return false;
    }

    /// @dev Expose internal function for testing
    function setPrice(uint256 id, uint256 price) external onlyOwner {
        _setPrice(id, price);
    }

    /// @dev Expose internal function for testing
    function setERC20Price(uint256 id, address token, uint256 price) external onlyOwner {
        _setERC20Price(id, token, price);
    }

    /// @dev Expose internal function for testing
    function setERC20Prices(uint256 id, PaymentToken[] calldata configs) external onlyOwner {
        _setERC20Prices(id, configs);
    }

    /// @dev Expose internal function for testing
    function setTreasury(address payable account) external onlyOwner {
        _setTreasury(account);
    }

    /// @dev Expose pause functionality for testing
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Expose unpause functionality for testing
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Helper to check balance for testing
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return balances[account][id];
    }
}

contract TokenPurchasableTest is BaseTestWithERC20s {
    MockTokenPurchasableV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenPurchasableV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "TokenPurchasable.t.sol:MockTokenPurchasableV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenPurchasableV1.initialize, (owner, treasury));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockTokenPurchasableV1(proxyAddress);
    }

    // ============ Initialization Tests ============= //

    function test_initialize() public view {
        assertEq(v1.treasury(), treasury);

        // Check that the storage slot for TokenPurchasable is correctly calculated to avoid storage collisions.
        assertEq(
            0x54c84cf2875b53587e3bd1a41cdb4ae126fe9184d0b1bd9183d4f9005d2ff600,
            keccak256(abi.encode(uint256(keccak256("tokenpurchasable.storage.TokenPurchasable")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }

    // ============ Price Management Tests ============= //

    function test_setPrice_succeeds() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;

        vm.expectEmit(true, false, false, true);
        emit TokenPurchasable.NativePriceSet(tokenId, price);

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        assertEq(v1.tokenPrice(tokenId), price);
    }

    function test_setPrice_zeroDisablesNativePurchases() public {
        uint256 tokenId = 1;

        // First set a price
        vm.prank(owner);
        v1.setPrice(tokenId, 1 ether);
        assertEq(v1.tokenPrice(tokenId), 1 ether);

        // Set price to zero
        vm.expectEmit(true, false, false, true);
        emit TokenPurchasable.NativePriceSet(tokenId, 0);

        vm.prank(owner);
        v1.setPrice(tokenId, 0);

        // Should revert when trying to get price
        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.TokenNotForSaleWithNativeCurrency.selector, tokenId));
        v1.tokenPrice(tokenId);
    }

    function testFuzz_setPrice(uint256 tokenId, uint256 price) public {
        vm.assume(price > 0);

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        assertEq(v1.tokenPrice(tokenId), price);
    }

    function testRevert_tokenPrice_TokenNotForSaleWithNativeCurrency() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.TokenNotForSaleWithNativeCurrency.selector, tokenId));
        v1.tokenPrice(tokenId);
    }

    function test_setERC20Price_succeeds() public {
        uint256 tokenId = 1;
        uint256 price = 100e6; // 100 USDC

        // Set ERC-20 token price
        vm.expectEmit(true, true, false, true);
        emit TokenPurchasable.ERC20PriceSet(tokenId, address(usdc), price);
        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        // Check price was set
        assertTrue(v1.isAcceptedERC20PaymentToken(tokenId, address(usdc)));
    }

    function test_setERC20Price_addsToAcceptedList() public {
        uint256 tokenId = 1;

        // Initially no accepted tokens
        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 0);

        // Set price for USDC
        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        // Check USDC is now accepted
        prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 1);
        assertEq(prices[0].token, address(usdc));
        assertEq(prices[0].price, 100e6);
    }

    function test_setERC20Price_updateExistingPrice() public {
        uint256 tokenId = 1;

        // Set initial price
        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        // Update price
        vm.expectEmit(true, true, false, true);
        emit TokenPurchasable.ERC20PriceSet(tokenId, address(usdc), 200e6);

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 200e6);

        // Should still have one token but with updated price
        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 1);
        assertEq(prices[0].price, 200e6);
    }

    function test_setERC20Price_zeroRemovesFromList() public {
        uint256 tokenId = 1;

        // Set price for two tokens
        vm.startPrank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);
        v1.setERC20Price(tokenId, address(usdt), 100e6);
        vm.stopPrank();

        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);

        // Remove USDC by setting price to 0
        vm.expectEmit(true, true, false, true);
        emit TokenPurchasable.ERC20PriceSet(tokenId, address(usdc), 0);

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 0);

        // Should only have USDT left
        prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 1);
        assertEq(prices[0].token, address(usdt));
        assertFalse(v1.isAcceptedERC20PaymentToken(tokenId, address(usdc)));
    }

    function test_setERC20Prices_batchSet() public {
        uint256 tokenId = 1;

        TokenPurchasable.PaymentToken[] memory configs = new TokenPurchasable.PaymentToken[](2);
        configs[0] = TokenPurchasable.PaymentToken(address(usdc), 100e6);
        configs[1] = TokenPurchasable.PaymentToken(address(usdt), 100e6);

        vm.prank(owner);
        v1.setERC20Prices(tokenId, configs);

        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);
    }

    function testRevert_setERC20Price_InvalidERC20PaymentToken() public {
        uint256 tokenId = 1;

        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.InvalidERC20PaymentToken.selector, address(0)));

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(0), 100e6);
    }

    function test_tokenERC20Prices_returnsAllAccepted() public {
        uint256 tokenId = 1;

        vm.startPrank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);
        v1.setERC20Price(tokenId, address(usdt), 200e6);
        vm.stopPrank();

        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);

        // Order might vary, so check both exist
        bool foundUSDC = false;
        bool foundUSDT = false;
        for (uint256 i = 0; i < prices.length; i++) {
            if (prices[i].token == address(usdc) && prices[i].price == 100e6) foundUSDC = true;
            if (prices[i].token == address(usdt) && prices[i].price == 200e6) foundUSDT = true;
        }
        assertTrue(foundUSDC);
        assertTrue(foundUSDT);
    }

    function test_isAcceptedERC20PaymentToken() public {
        uint256 tokenId = 1;

        assertFalse(v1.isAcceptedERC20PaymentToken(tokenId, address(usdc)));

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        assertTrue(v1.isAcceptedERC20PaymentToken(tokenId, address(usdc)));
        assertFalse(v1.isAcceptedERC20PaymentToken(tokenId, address(usdt)));
    }

    // ============ Native Currency Purchase Tests ============= //

    function test_purchase_exactPayment() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 amount = 3;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        // Give alice exact ETH needed
        deal(alice, price * amount);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, alice, tokenId, amount, price * amount);

        vm.prank(alice);
        v1.purchase{ value: price * amount }(tokenId, amount);

        assertEq(v1.balanceOf(alice, tokenId), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + price * amount);
        assertEq(alice.balance, 0);
    }

    function test_purchase_withRefund() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 amount = 2;
        uint256 payment = 3 ether;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, payment);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        v1.purchase{ value: payment }(tokenId, amount);

        assertEq(v1.balanceOf(alice, tokenId), amount);
        assertEq(treasury.balance, treasuryBalanceBefore + price * amount);
        assertEq(alice.balance, payment - (price * amount)); // Refund received
    }

    function test_purchaseFor_succeeds() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 amount = 2;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, price * amount);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, bob, tokenId, amount, price * amount);

        vm.prank(alice);
        v1.purchaseFor{ value: price * amount }(bob, tokenId, amount);

        assertEq(v1.balanceOf(bob, tokenId), amount);
        assertEq(v1.balanceOf(alice, tokenId), 0);
    }

    function test_purchase_mintsCorrectAmount() public {
        uint256 tokenId = 1;
        uint256 price = 0.1 ether;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, 1 ether);

        // Purchase different amounts
        vm.startPrank(alice);
        v1.purchase{ value: price * 1 }(tokenId, 1);
        assertEq(v1.balanceOf(alice, tokenId), 1);

        v1.purchase{ value: price * 5 }(tokenId, 5);
        assertEq(v1.balanceOf(alice, tokenId), 6);
        vm.stopPrank();
    }

    function testFuzz_purchase(uint256 tokenId, uint256 amount, uint256 payment) public {
        amount = bound(amount, 1, 1000);
        uint256 price = 0.01 ether;
        payment = bound(payment, price * amount, 100 ether);

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, payment);

        vm.prank(alice);
        v1.purchase{ value: payment }(tokenId, amount);

        assertEq(v1.balanceOf(alice, tokenId), amount);
        assertEq(alice.balance, payment - (price * amount));
    }

    function testRevert_purchase_InsufficientPayment() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 amount = 2;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, 1.5 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPurchasable.InsufficientPayment.selector, tokenId, amount, price * amount, 1.5 ether
            )
        );

        vm.prank(alice);
        v1.purchase{ value: 1.5 ether }(tokenId, amount);
    }

    function testRevert_purchase_InvalidTokenQuantity() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setPrice(tokenId, 1 ether);

        deal(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.InvalidTokenQuantity.selector, 0));
        v1.purchase{ value: 1 ether }(tokenId, 0);
    }

    function testRevert_purchaseFor_InvalidReceiverAddress() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setPrice(tokenId, 1 ether);

        deal(alice, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.InvalidReceiverAddress.selector, address(0)));

        vm.prank(alice);
        v1.purchaseFor{ value: 1 ether }(address(0), tokenId, 1);
    }

    function testRevert_purchase_TokenNotForSaleWithNativeCurrency() public {
        uint256 tokenId = 1;

        // Don't set a price

        deal(alice, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.TokenNotForSaleWithNativeCurrency.selector, tokenId));

        vm.prank(alice);
        v1.purchase{ value: 1 ether }(tokenId, 1);
    }

    // ============ ERC20 Purchase Tests ============= //

    function test_purchaseWithERC20_succeeds() public {
        uint256 tokenId = 1;
        uint256 price = 100e6; // 100 USDC
        uint256 amount = 3;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        // Give alice USDC and approve
        deal(address(usdc), alice, price * amount);
        vm.prank(alice);
        usdc.approve(address(v1), price * amount);

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, alice, tokenId, amount, price * amount);

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, amount);

        assertEq(v1.balanceOf(alice, tokenId), amount);
        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + price * amount);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_purchaseWithERC20For_succeeds() public {
        uint256 tokenId = 1;
        uint256 price = 100e6;
        uint256 amount = 2;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        deal(address(usdc), alice, price * amount);
        vm.prank(alice);
        usdc.approve(address(v1), price * amount);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, bob, tokenId, amount, price * amount);

        vm.prank(alice);
        v1.purchaseWithERC20For(bob, address(usdc), tokenId, amount);

        assertEq(v1.balanceOf(bob, tokenId), amount);
        assertEq(v1.balanceOf(alice, tokenId), 0);
    }

    function test_purchaseWithERC20_multipleAcceptedTokens() public {
        uint256 tokenId = 1;

        vm.startPrank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);
        v1.setERC20Price(tokenId, address(usdt), 100e6);
        vm.stopPrank();

        // Purchase with USDC
        deal(address(usdc), alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(v1), 100e6);
        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);

        // Purchase with USDT
        deal(address(usdt), bob, 100e6);
        vm.prank(bob);
        usdt.approve(address(v1), 100e6);
        vm.prank(bob);
        v1.purchaseWithERC20(address(usdt), tokenId, 1);

        assertEq(v1.balanceOf(alice, tokenId), 1);
        assertEq(v1.balanceOf(bob, tokenId), 1);
    }

    function test_purchaseWithERC20_transfersExactAmount() public {
        uint256 tokenId = 1;
        uint256 price = 100e6;
        uint256 amount = 5;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        // Give alice extra USDC
        deal(address(usdc), alice, price * amount + 1000e6);
        vm.prank(alice);
        usdc.approve(address(v1), price * amount);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, amount);

        assertEq(usdc.balanceOf(alice), aliceBalanceBefore - price * amount);
        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + price * amount);
    }

    function testRevert_purchaseWithERC20_InsufficientERC20Allowance() public {
        uint256 tokenId = 1;
        uint256 price = 100e6;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        deal(address(usdc), alice, price * 2);
        vm.prank(alice);
        usdc.approve(address(v1), price - 1); // Approve less than needed

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenPurchasable.InsufficientERC20Allowance.selector, address(usdc), price, price - 1
            )
        );

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);
    }

    function testRevert_purchaseWithERC20_InsufficientERC20Balance() public {
        uint256 tokenId = 1;
        uint256 price = 100e6;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        deal(address(usdc), alice, price - 1); // Give less than needed
        vm.prank(alice);
        usdc.approve(address(v1), price);

        vm.expectRevert(
            abi.encodeWithSelector(TokenPurchasable.InsufficientERC20Balance.selector, address(usdc), price, price - 1)
        );

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);
    }

    function testRevert_purchaseWithERC20_TokenNotForSaleWithERC20() public {
        uint256 tokenId = 1;

        // Don't set ERC20 price

        deal(address(usdc), alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(v1), 100e6);

        vm.expectRevert(
            abi.encodeWithSelector(TokenPurchasable.TokenNotForSaleWithERC20.selector, tokenId, address(usdc))
        );

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);
    }

    function testRevert_purchaseWithERC20_InvalidERC20PaymentToken() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        // Try to purchase with non-accepted token
        deal(address(usdt), alice, 100e6);
        vm.prank(alice);
        usdt.approve(address(v1), 100e6);

        vm.expectRevert(
            abi.encodeWithSelector(TokenPurchasable.TokenNotForSaleWithERC20.selector, tokenId, address(usdt))
        );

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdt), tokenId, 1);
    }

    // ============ Treasury Management Tests ============= //

    function test_setTreasury_succeeds() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectEmit(true, true, false, false);
        emit TokenPurchasable.TreasuryUpdated(owner, newTreasury);

        vm.prank(owner);
        v1.setTreasury(newTreasury);

        assertEq(v1.treasury(), newTreasury);
    }

    function testRevert_setTreasury_InvalidTreasuryAddress() public {
        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.InvalidTreasuryAddress.selector, address(0)));

        vm.prank(owner);
        v1.setTreasury(payable(address(0)));
    }

    function test_purchase_sendsNativeToTreasury() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;

        vm.prank(owner);
        v1.setPrice(tokenId, price);

        deal(alice, price);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(alice);
        v1.purchase{ value: price }(tokenId, 1);

        assertEq(treasury.balance, treasuryBalanceBefore + price);
    }

    function test_purchaseWithERC20_sendsTokensToTreasury() public {
        uint256 tokenId = 1;
        uint256 price = 100e6;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), price);

        deal(address(usdc), alice, price);
        vm.prank(alice);
        usdc.approve(address(v1), price);

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);

        assertEq(usdc.balanceOf(treasury), treasuryBalanceBefore + price);
    }

    function test_treasury_returnsCurrentAddress() public view {
        assertEq(v1.treasury(), treasury);
    }

    // ============ Pausable Tests ============= //

    function test_pause_succeeds() public {
        assertFalse(v1.paused());

        vm.expectEmit(false, false, false, true);
        emit PausableUpgradeable.Paused(owner);

        vm.prank(owner);
        v1.pause();

        assertTrue(v1.paused());
    }

    function test_unpause_succeeds() public {
        vm.prank(owner);
        v1.pause();
        assertTrue(v1.paused());

        vm.expectEmit(false, false, false, true);
        emit PausableUpgradeable.Unpaused(owner);

        vm.prank(owner);
        v1.unpause();

        assertFalse(v1.paused());
    }

    function testRevert_purchase_whenPaused() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setPrice(tokenId, 1 ether);

        vm.prank(owner);
        v1.pause();

        deal(alice, 1 ether);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(alice);
        v1.purchase{ value: 1 ether }(tokenId, 1);
    }

    function testRevert_purchaseFor_whenPaused() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setPrice(tokenId, 1 ether);

        vm.prank(owner);
        v1.pause();

        deal(alice, 1 ether);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(alice);
        v1.purchaseFor{ value: 1 ether }(bob, tokenId, 1);
    }

    function testRevert_purchaseWithERC20_whenPaused() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        vm.prank(owner);
        v1.pause();

        deal(address(usdc), alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(v1), 100e6);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 1);
    }

    function testRevert_purchaseWithERC20For_whenPaused() public {
        uint256 tokenId = 1;

        vm.prank(owner);
        v1.setERC20Price(tokenId, address(usdc), 100e6);

        vm.prank(owner);
        v1.pause();

        deal(address(usdc), alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(v1), 100e6);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(alice);
        v1.purchaseWithERC20For(bob, address(usdc), tokenId, 1);
    }
}
