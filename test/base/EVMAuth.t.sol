// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenEnumerable } from "src/base/TokenEnumerable.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { BaseTestWithAccessControlAndERC20s } from "test/_helpers/BaseTest.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MockEVMAuthV1 is EVMAuth {
    // Mapping of address to token ID to balance, simulating an ERC-1155 or ERC-6909 implementation
    mapping(address => mapping(uint256 => uint256)) public balances;

    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param roleGrants The initial set of role grants to be applied.
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        RoleGrant[] calldata roleGrants
    ) public initializer {
        __MockEVMAuthV1_init(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param roleGrants The initial set of role grants to be applied.
     */
    function __MockEVMAuthV1_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        RoleGrant[] calldata roleGrants
    ) internal onlyInitializing {
        __EVMAuth_init(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants);
        __MockEVMAuthV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockEVMAuthV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc TokenPurchasable
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        _updateBalanceRecords(address(0), to, id, amount);
        balances[to][id] += amount;
    }

    /// @inheritdoc TokenEphemeral
    function _burnPrunedTokens(address account, uint256 id, uint256 amount) internal virtual override {
        // This is only called by pruneBalanceRecords, so we don't need to update balance records again
        balances[account][id] -= amount;
    }
}

contract EVMAuthTest is BaseTestWithAccessControlAndERC20s {
    MockEVMAuthV1 internal v1;

    // ============ Test Setup ============= //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuthV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth.t.sol:MockEVMAuthV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, owner);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        return abi.encodeCall(MockEVMAuthV1.initialize, (2 days, owner, treasury, roleGrants));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockEVMAuthV1(proxyAddress);
    }

    function _grantRoles() internal override {
        // Roles are granted during initialization
    }

    // ============ Initialization Tests ============= //

    function test_initialize() public view {
        // Test initial state
        assertEq(v1.nextTokenID(), 1);
        assertEq(v1.treasury(), treasury);

        // Test role assignments
        assertTrue(v1.hasRole(v1.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(v1.hasRole(v1.UPGRADE_MANAGER_ROLE(), owner));
        assertTrue(v1.hasRole(v1.ACCESS_MANAGER_ROLE(), accessManager));
        assertTrue(v1.hasRole(v1.TOKEN_MANAGER_ROLE(), tokenManager));
        assertTrue(v1.hasRole(v1.MINTER_ROLE(), minter));
        assertTrue(v1.hasRole(v1.BURNER_ROLE(), burner));
        assertTrue(v1.hasRole(v1.TREASURER_ROLE(), treasurer));
    }

    // ============ Token Creation Tests ============= //

    function test_createToken_basic() public {
        // Prepare token config
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600, // 1 hour
            transferable: true
        });

        // Create token
        vm.prank(tokenManager);
        vm.expectEmit(true, false, false, true);
        emit EVMAuth.EVMAuthTokenConfigured(1, config);
        uint256 tokenId = v1.createToken(config);

        // Verify token was created
        assertEq(tokenId, 1);
        assertTrue(v1.exists(tokenId));
        assertEq(v1.tokenPrice(tokenId), 1 ether);
        assertEq(v1.tokenTTL(tokenId), 3600);
        assertTrue(v1.isTransferable(tokenId));
    }

    function test_createToken_withERC20Prices() public {
        // Prepare ERC20 prices
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](2);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e18 });
        erc20Prices[1] = TokenPurchasable.PaymentToken({ token: address(usdt), price: 50e6 });

        // Prepare token config
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0.5 ether,
            erc20Prices: erc20Prices,
            ttl: 0, // Permanent
            transferable: false
        });

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        // Verify token configuration
        assertEq(tokenId, 1);
        assertEq(v1.tokenPrice(tokenId), 0.5 ether);

        // Verify ERC20 prices
        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);
        assertEq(prices[0].token, address(usdc));
        assertEq(prices[0].price, 100e18);
        assertEq(prices[1].token, address(usdt));
        assertEq(prices[1].price, 50e6);

        assertEq(v1.tokenTTL(tokenId), 0);
        assertFalse(v1.isTransferable(tokenId));
    }

    function test_createToken_multipleTokens() public {
        EVMAuth.EVMAuthTokenConfig memory config1 = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        EVMAuth.EVMAuthTokenConfig memory config2 = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 7200,
            transferable: false
        });

        // Create first token
        vm.prank(tokenManager);
        uint256 tokenId1 = v1.createToken(config1);
        assertEq(tokenId1, 1);

        // Create second token
        vm.prank(tokenManager);
        uint256 tokenId2 = v1.createToken(config2);
        assertEq(tokenId2, 2);

        // Verify both tokens have correct configs
        assertEq(v1.tokenPrice(tokenId1), 1 ether);
        assertEq(v1.tokenTTL(tokenId1), 3600);
        assertTrue(v1.isTransferable(tokenId1));

        assertEq(v1.tokenPrice(tokenId2), 2 ether);
        assertEq(v1.tokenTTL(tokenId2), 7200);
        assertFalse(v1.isTransferable(tokenId2));
    }

    function testRevert_createToken_AccessControlUnauthorizedAccount() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        // Try to create token without TOKEN_MANAGER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), v1.TOKEN_MANAGER_ROLE()
            )
        );
        v1.createToken(config);
    }

    // ============ Token Update Tests ============= //

    function test_updateToken_basic() public {
        // Create initial token
        EVMAuth.EVMAuthTokenConfig memory initialConfig = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(initialConfig);

        // Update token config
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 7200,
            transferable: false
        });

        vm.prank(tokenManager);
        vm.expectEmit(true, false, false, true);
        emit EVMAuth.EVMAuthTokenConfigured(tokenId, newConfig);
        v1.updateToken(tokenId, newConfig);

        // Verify updated configuration
        assertEq(v1.tokenPrice(tokenId), 2 ether);
        assertEq(v1.tokenTTL(tokenId), 7200);
        assertFalse(v1.isTransferable(tokenId));
    }

    function test_updateToken_withERC20Prices() public {
        // Create initial token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Prepare new ERC20 prices
        TokenPurchasable.PaymentToken[] memory newErc20Prices = new TokenPurchasable.PaymentToken[](1);
        newErc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 200e18 });

        // Update with ERC20 prices
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 0.1 ether,
            erc20Prices: newErc20Prices,
            ttl: 86400,
            transferable: false
        });

        vm.prank(tokenManager);
        v1.updateToken(tokenId, newConfig);

        // Verify updated configuration
        assertEq(v1.tokenPrice(tokenId), 0.1 ether);

        // Verify ERC20 price was updated
        TokenPurchasable.PaymentToken[] memory updatedPrices = v1.tokenERC20Prices(tokenId);
        assertEq(updatedPrices.length, 1);
        assertEq(updatedPrices[0].token, address(usdc));
        assertEq(updatedPrices[0].price, 200e18);

        assertEq(v1.tokenTTL(tokenId), 86400);
        assertFalse(v1.isTransferable(tokenId));
    }

    function testRevert_updateToken_InvalidTokenID() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        // Try to update non-existent token
        vm.prank(tokenManager);
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.updateToken(999, config);
    }

    function testRevert_updateToken_AccessControlUnauthorizedAccount() public {
        // Create a token first
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 3600,
                transferable: true
            })
        );

        // Try to update without TOKEN_MANAGER_ROLE
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 7200,
            transferable: false
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), v1.TOKEN_MANAGER_ROLE()
            )
        );
        v1.updateToken(tokenId, newConfig);
    }

    // ============ Treasury Management Tests ============= //

    function test_setTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        // Update treasury
        vm.prank(treasurer);
        vm.expectEmit(false, true, false, true);
        emit TokenPurchasable.TreasuryUpdated(treasurer, newTreasury);
        v1.setTreasury(newTreasury);

        // Verify treasury was updated
        assertEq(v1.treasury(), newTreasury);
    }

    function testRevert_setTreasury_AccessControlUnauthorizedAccount() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        // Try to update treasury without TREASURER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), v1.TREASURER_ROLE()
            )
        );
        v1.setTreasury(newTreasury);
    }

    function testRevert_setTreasury_InvalidTreasuryAddress() public {
        // Try to set treasury to zero address
        vm.prank(treasurer);
        vm.expectRevert(abi.encodeWithSelector(TokenPurchasable.InvalidTreasuryAddress.selector, address(0)));
        v1.setTreasury(payable(address(0)));
    }

    // ============ Token Config Getter Tests ============= //

    function test_tokenConfig() public {
        // Prepare ERC20 prices
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](2);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e18 });
        erc20Prices[1] = TokenPurchasable.PaymentToken({ token: address(usdt), price: 50e6 });

        // Create token with full config
        EVMAuth.EVMAuthTokenConfig memory config =
            EVMAuth.EVMAuthTokenConfig({ price: 1.5 ether, erc20Prices: erc20Prices, ttl: 3600, transferable: true });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        // Get token config
        EVMAuth.EVMAuthToken memory tokenInfo = v1.tokenConfig(tokenId);

        // Verify all fields
        assertEq(tokenInfo.id, tokenId);
        assertEq(tokenInfo.config.price, 1.5 ether);
        assertEq(tokenInfo.config.ttl, 3600);
        assertTrue(tokenInfo.config.transferable);
        assertEq(tokenInfo.config.erc20Prices.length, 2);
        assertEq(tokenInfo.config.erc20Prices[0].token, address(usdc));
        assertEq(tokenInfo.config.erc20Prices[0].price, 100e18);
        assertEq(tokenInfo.config.erc20Prices[1].token, address(usdt));
        assertEq(tokenInfo.config.erc20Prices[1].price, 50e6);
    }

    function testRevert_tokenConfig_InvalidTokenID() public {
        // Try to get config for non-existent token
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.tokenConfig(999);
    }

    // ============ Individual Getter Tests ============= //

    function test_tokenPrice() public {
        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 2.5 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Test getter
        assertEq(v1.tokenPrice(tokenId), 2.5 ether);
    }

    function testRevert_tokenPrice_InvalidTokenID() public {
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.tokenPrice(999);
    }

    function test_tokenERC20Prices() public {
        // Prepare ERC20 prices
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](2);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e18 });
        erc20Prices[1] = TokenPurchasable.PaymentToken({ token: address(usdt), price: 50e6 });

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({ price: 1 ether, erc20Prices: erc20Prices, ttl: 0, transferable: true })
        );

        // Test getter
        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);
        assertEq(prices[0].token, address(usdc));
        assertEq(prices[0].price, 100e18);
        assertEq(prices[1].token, address(usdt));
        assertEq(prices[1].price, 50e6);
    }

    function testRevert_tokenERC20Prices_InvalidTokenID() public {
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.tokenERC20Prices(999);
    }

    function test_tokenTTL() public {
        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 86400, // 1 day
                transferable: true
            })
        );

        // Test getter
        assertEq(v1.tokenTTL(tokenId), 86400);
    }

    function testRevert_tokenTTL_InvalidTokenID() public {
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.tokenTTL(999);
    }

    function test_isTransferable() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId1 = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Create non-transferable token
        vm.prank(tokenManager);
        uint256 tokenId2 = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: false
            })
        );

        // Test getters
        assertTrue(v1.isTransferable(tokenId1));
        assertFalse(v1.isTransferable(tokenId2));
    }

    function testRevert_isTransferable_InvalidTokenID() public {
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        v1.isTransferable(999);
    }

    // ============ Purchase Integration Tests ============= //

    function test_purchase_withNativeCurrency() public {
        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 3600,
                transferable: true
            })
        );

        // Purchase token
        uint256 initialTreasuryBalance = treasury.balance;
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        v1.purchase{ value: 1 ether }(tokenId, 1);

        // Verify purchase
        assertEq(v1.balances(alice, tokenId), 1);
        assertEq(treasury.balance, initialTreasuryBalance + 1 ether);
        assertEq(alice.balance, 1 ether); // Refund of overpayment
    }

    function test_purchase_withERC20() public {
        // Prepare ERC20 prices
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e18 });

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({ price: 1 ether, erc20Prices: erc20Prices, ttl: 0, transferable: false })
        );

        // Setup ERC20 balance and approval
        deal(address(usdc), alice, 500e18);
        vm.prank(alice);
        usdc.approve(address(v1), 200e18);

        // Purchase with ERC20
        uint256 initialTreasuryBalance = usdc.balanceOf(treasury);
        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 2);

        // Verify purchase
        assertEq(v1.balances(alice, tokenId), 2);
        assertEq(usdc.balanceOf(treasury), initialTreasuryBalance + 200e18);
        assertEq(usdc.balanceOf(alice), 300e18);
    }

    // ============ Access Control Tests ============= //

    function test_pause() public {
        // Pause contract
        vm.prank(accessManager);
        v1.pause();
        assertTrue(v1.paused());

        // Unpause contract
        vm.prank(accessManager);
        v1.unpause();
        assertFalse(v1.paused());
    }

    function test_freezeAccount() public {
        // Freeze account
        vm.prank(accessManager);
        v1.freezeAccount(alice);
        assertTrue(v1.isFrozen(alice));

        // Unfreeze account
        vm.prank(accessManager);
        v1.unfreezeAccount(alice);
        assertFalse(v1.isFrozen(alice));
    }

    // ============ Pruning Tests ============= //

    function test_pruneBalanceRecords() public {
        uint48 ttl = 10;

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl,
                transferable: true
            })
        );

        // Fund Alice
        vm.deal(alice, 10 ether);

        // Mint tokens
        vm.prank(alice);
        v1.purchase{ value: 5 ether }(tokenId, 5);
        assertEq(v1.balanceOf(alice, tokenId), 5);
        assertEq(v1.balances(alice, tokenId), 5);

        // Let tokens expire
        vm.warp(block.timestamp + ttl * 2);

        // Verify balanceOf does not show a balance, but the underlying balance still exists
        assertEq(v1.balanceOf(alice, tokenId), 0);
        assertEq(v1.balances(alice, tokenId), 5);

        // Expect the PrunedTokensBurned event to be emitted when pruning
        vm.expectEmit(true, true, false, true);
        emit TokenEphemeral.ExpiredTokensPruned(alice, tokenId, 5);
        v1.pruneBalanceRecords(alice, tokenId);

        // Verify the underlying balance has been updated
        assertEq(v1.balanceOf(alice, tokenId), 0);
        assertEq(v1.balances(alice, tokenId), 0);

        // Verify all records are pruned
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
        assertEq(records.length, 0);
    }
}
