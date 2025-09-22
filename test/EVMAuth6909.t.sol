// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { AccountFreezable } from "src/base/AccountFreezable.sol";
import { EVMAuth } from "src/base/EVMAuth.sol";
import { EVMAuth6909 } from "src/EVMAuth6909.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenEnumerable } from "src/base/TokenEnumerable.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { TokenTransferable } from "src/base/TokenTransferable.sol";
import { BaseTestWithAccessControlAndERC20s } from "test/_helpers/BaseTest.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC6909 } from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

contract EVMAuth6909Test is BaseTestWithAccessControlAndERC20s {
    EVMAuth6909 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new EVMAuth6909());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth6909.sol:EVMAuth6909";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, owner);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        return abi.encodeCall(
            EVMAuth6909.initialize,
            (2 days, owner, treasury, roleGrants, "https://contract-cdn-domain/contract-metadata.json")
        );
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = EVMAuth6909(proxyAddress);
    }

    function _grantRoles() internal override {
        // Roles are granted during initialization
    }

    // ============ Initialization Tests ============= //

    function test_initialize() public view {
        assertEq(v1.nextTokenID(), 1);
        assertEq(v1.treasury(), treasury);
        assertEq(v1.contractURI(), "https://contract-cdn-domain/contract-metadata.json");

        assertTrue(v1.hasRole(v1.UPGRADE_MANAGER_ROLE(), owner), "Upgrade manager role not set correctly");
        assertTrue(v1.hasRole(v1.ACCESS_MANAGER_ROLE(), accessManager), "Access manager role not set correctly");
        assertTrue(v1.hasRole(v1.TOKEN_MANAGER_ROLE(), tokenManager), "Token manager role not set correctly");
        assertTrue(v1.hasRole(v1.MINTER_ROLE(), minter), "Minter role not set correctly");
        assertTrue(v1.hasRole(v1.BURNER_ROLE(), burner), "Burner role not set correctly");
        assertTrue(v1.hasRole(v1.TREASURER_ROLE(), treasurer), "Treasurer role not set correctly");
    }

    // ============ ERC6909 Standard Compliance Tests ============= //

    function test_mint_withMinterRole() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Create token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0, // Permanent
                transferable: true
            })
        );

        // Mint tokens
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(minter, address(0), alice, tokenId, amount);

        vm.prank(minter);
        v1.mint(alice, tokenId, amount);

        assertEq(v1.balanceOf(alice, tokenId), amount);
    }

    function testRevert_mint_AccessControlUnauthorizedAccount() public {
        // Try to mint without MINTER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, v1.MINTER_ROLE())
        );
        vm.prank(alice);
        v1.mint(alice, 1, 100);
    }

    function test_burn_withBurnerRole() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        uint256 burnAmount = 60;

        // Create token and mint first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        vm.prank(minter);
        v1.mint(alice, tokenId, amount);

        // Burn tokens
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(burner, alice, address(0), tokenId, burnAmount);

        vm.prank(burner);
        v1.burn(alice, tokenId, burnAmount);

        assertEq(v1.balanceOf(alice, tokenId), amount - burnAmount);
    }

    function testRevert_burn_AccessControlUnauthorizedAccount() public {
        // Try to burn without BURNER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, v1.BURNER_ROLE())
        );
        vm.prank(alice);
        v1.burn(alice, 1, 100);
    }

    function test_transfer_direct() public {
        uint256 tokenId = _createAndMintToken(alice, 100);
        uint256 transferAmount = 40;

        // Direct transfer
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(alice, alice, bob, tokenId, transferAmount);

        vm.prank(alice);
        v1.transfer(bob, tokenId, transferAmount);

        assertEq(v1.balanceOf(alice, tokenId), 60);
        assertEq(v1.balanceOf(bob, tokenId), 40);
    }

    function test_approve_and_allowance() public {
        uint256 tokenId = 1;
        uint256 amount = 200;

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Approval(alice, bob, tokenId, amount);

        vm.prank(alice);
        v1.approve(bob, tokenId, amount);

        assertEq(v1.allowance(alice, bob, tokenId), amount);
    }

    function test_transferFrom_withAllowance() public {
        uint256 tokenId = _createAndMintToken(alice, 100);
        uint256 transferAmount = 30;

        // Alice approves Bob to spend tokens
        vm.prank(alice);
        v1.approve(bob, tokenId, transferAmount);

        // Bob transfers from Alice to Carol
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(bob, alice, carol, tokenId, transferAmount);

        vm.prank(bob);
        v1.transferFrom(alice, carol, tokenId, transferAmount);

        assertEq(v1.balanceOf(alice, tokenId), 70);
        assertEq(v1.balanceOf(carol, tokenId), 30);
        assertEq(v1.allowance(alice, bob, tokenId), 0); // Allowance consumed
    }

    function test_setOperator_and_isOperator() public {
        // Alice sets Bob as operator
        vm.expectEmit(true, true, false, true);
        emit IERC6909.OperatorSet(alice, bob, true);

        vm.prank(alice);
        v1.setOperator(bob, true);

        assertTrue(v1.isOperator(alice, bob));

        // Alice revokes Bob's operator status
        vm.expectEmit(true, true, false, true);
        emit IERC6909.OperatorSet(alice, bob, false);

        vm.prank(alice);
        v1.setOperator(bob, false);

        assertFalse(v1.isOperator(alice, bob));
    }

    function test_transferFrom_withOperator() public {
        uint256 tokenId = _createAndMintToken(alice, 100);
        uint256 transferAmount = 50;

        // Alice sets Bob as operator
        vm.prank(alice);
        v1.setOperator(bob, true);

        // Bob transfers from Alice to Carol (no allowance needed)
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(bob, alice, carol, tokenId, transferAmount);

        vm.prank(bob);
        v1.transferFrom(alice, carol, tokenId, transferAmount);

        assertEq(v1.balanceOf(alice, tokenId), 50);
        assertEq(v1.balanceOf(carol, tokenId), 50);
    }

    function test_balanceOf_query() public {
        uint256 tokenId = _createAndMintToken(alice, 150);

        assertEq(v1.balanceOf(alice, tokenId), 150);
        assertEq(v1.balanceOf(bob, tokenId), 0);
    }

    // ============ Token Creation & Management Tests ============= //

    function test_createToken_permanent() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0, // Permanent
            transferable: true
        });

        vm.expectEmit(true, false, false, true);
        emit EVMAuth.EVMAuthTokenConfigured(1, config);

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        assertEq(tokenId, 1);
        assertTrue(v1.exists(tokenId));
        assertEq(v1.tokenPrice(tokenId), 2 ether);
        assertEq(v1.tokenTTL(tokenId), 0);
        assertTrue(v1.isTransferable(tokenId));
    }

    function test_createToken_ephemeral() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600, // 1 hour
            transferable: false
        });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        assertEq(tokenId, 1);
        assertEq(v1.tokenTTL(tokenId), 3600);
        assertFalse(v1.isTransferable(tokenId));
    }

    function test_createToken_withERC20Prices() public {
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](2);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e6 });
        erc20Prices[1] = TokenPurchasable.PaymentToken({ token: address(usdt), price: 100e6 });

        EVMAuth.EVMAuthTokenConfig memory config =
            EVMAuth.EVMAuthTokenConfig({ price: 0.5 ether, erc20Prices: erc20Prices, ttl: 7200, transferable: true });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);
        assertEq(prices[0].token, address(usdc));
        assertEq(prices[0].price, 100e6);
    }

    function test_updateToken_configuration() public {
        // Create initial token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 3600,
                transferable: true
            })
        );

        // Update configuration
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 7200,
            transferable: false
        });

        vm.expectEmit(true, false, false, true);
        emit EVMAuth.EVMAuthTokenConfigured(tokenId, newConfig);

        vm.prank(tokenManager);
        v1.updateToken(tokenId, newConfig);

        assertEq(v1.tokenPrice(tokenId), 2 ether);
        assertEq(v1.tokenTTL(tokenId), 7200);
        assertFalse(v1.isTransferable(tokenId));
    }

    function testRevert_updateToken_InvalidTokenID() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 999));
        vm.prank(tokenManager);
        v1.updateToken(999, config);
    }

    function test_tokenConfig_fullInformation() public {
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 50e6 });

        EVMAuth.EVMAuthTokenConfig memory config =
            EVMAuth.EVMAuthTokenConfig({ price: 1.5 ether, erc20Prices: erc20Prices, ttl: 86400, transferable: true });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        EVMAuth.EVMAuthToken memory tokenInfo = v1.tokenConfig(tokenId);
        assertEq(tokenInfo.id, tokenId);
        assertEq(tokenInfo.config.price, 1.5 ether);
        assertEq(tokenInfo.config.ttl, 86400);
        assertTrue(tokenInfo.config.transferable);
        assertEq(tokenInfo.config.erc20Prices.length, 1);
    }

    // ============ Purchase Integration Tests ============= //

    function test_purchase_withNativeCurrency() public {
        uint256 tokenId = _createPurchasableToken(1 ether);

        uint256 initialTreasuryBalance = treasury.balance;
        vm.deal(alice, 2 ether);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, alice, tokenId, 1, 1 ether);

        vm.prank(alice);
        v1.purchase{ value: 1 ether }(tokenId, 1);

        assertEq(v1.balanceOf(alice, tokenId), 1);
        assertEq(treasury.balance, initialTreasuryBalance + 1 ether);
    }

    function test_purchase_withERC20() public {
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e6 });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({ price: 1 ether, erc20Prices: erc20Prices, ttl: 0, transferable: true })
        );

        deal(address(usdc), alice, 500e6);
        vm.prank(alice);
        usdc.approve(address(v1), 200e6);

        uint256 initialTreasuryBalance = usdc.balanceOf(treasury);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, alice, tokenId, 2, 200e6);

        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, 2);

        assertEq(v1.balanceOf(alice, tokenId), 2);
        assertEq(usdc.balanceOf(treasury), initialTreasuryBalance + 200e6);
    }

    function test_purchaseFor_functionality() public {
        uint256 tokenId = _createPurchasableToken(0.5 ether);

        vm.deal(alice, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, bob, tokenId, 1, 0.5 ether);

        vm.prank(alice);
        v1.purchaseFor{ value: 0.5 ether }(bob, tokenId, 1);

        assertEq(v1.balanceOf(alice, tokenId), 0);
        assertEq(v1.balanceOf(bob, tokenId), 1);
    }

    function test_purchaseWithERC20For_functionality() public {
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 75e6 });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({ price: 1 ether, erc20Prices: erc20Prices, ttl: 0, transferable: true })
        );

        deal(address(usdc), alice, 150e6);
        vm.prank(alice);
        usdc.approve(address(v1), 150e6);

        vm.expectEmit(true, true, true, true);
        emit TokenPurchasable.TokenPurchased(alice, carol, tokenId, 2, 150e6);

        vm.prank(alice);
        v1.purchaseWithERC20For(carol, address(usdc), tokenId, 2);

        assertEq(v1.balanceOf(alice, tokenId), 0);
        assertEq(v1.balanceOf(carol, tokenId), 2);
    }

    // ============ Ephemeral Token Behavior Tests ============= //

    function test_ephemeralToken_expiration() public {
        // Create ephemeral token
        uint256 ttl = 3600; // 1 hour
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl,
                transferable: true
            })
        );

        // Mint tokens to Alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100);

        // Initially Alice should have tokens
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Fast forward half the TTL - tokens should still be valid
        vm.warp(block.timestamp + ttl / 2);
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Fast forward past TTL - tokens should be expired
        vm.warp(block.timestamp + ttl);
        assertEq(v1.balanceOf(alice, tokenId), 0);
    }

    function test_ephemeralToken_multipleExpirations() public {
        uint48 ttl1 = 1800; // 30 minutes
        uint48 ttl2 = 3600; // 1 hour
        uint256 bucketSize1 = ttl1 / 100; // DEFAULT_MAX_BALANCE_RECORDS = 100
        uint256 bucketSize2 = ttl2 / 100; // DEFAULT_MAX_BALANCE_RECORDS = 100

        // Create two ephemeral tokens with different TTLs
        vm.startPrank(tokenManager);
        uint256 tokenId1 = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl1,
                transferable: true
            })
        );
        uint256 tokenId2 = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl2,
                transferable: true
            })
        );
        vm.stopPrank();

        // Mint tokens
        vm.startPrank(minter);
        v1.mint(alice, tokenId1, 50);
        v1.mint(alice, tokenId2, 100);
        vm.stopPrank();

        // Initially both should have full balance
        assertEq(v1.balanceOf(alice, tokenId1), 50);
        assertEq(v1.balanceOf(alice, tokenId2), 100);

        // Fast forward past first expiration but before second
        vm.warp(block.timestamp + ttl1 + bucketSize1);
        assertEq(v1.balanceOf(alice, tokenId1), 0); // Expired
        assertEq(v1.balanceOf(alice, tokenId2), 100); // Still valid

        // Fast forward past second expiration
        vm.warp(block.timestamp + (ttl2 - ttl1 + bucketSize2));
        assertEq(v1.balanceOf(alice, tokenId1), 0); // Still expired
        assertEq(v1.balanceOf(alice, tokenId2), 0); // Now expired
    }

    function test_permanentToken_noExpiration() public {
        // Create permanent token (TTL = 0)
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0, // Permanent
                transferable: true
            })
        );

        // Mint tokens
        vm.prank(minter);
        v1.mint(alice, tokenId, 100);

        // Initially alice should have full balance
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Fast forward a very long time - tokens should still be valid
        vm.warp(block.timestamp + 365 days);
        assertEq(v1.balanceOf(alice, tokenId), 100);
    }

    function test_ephemeralToken_balanceRecords() public {
        // Create ephemeral token
        uint256 ttl = 7200; // 2 hours
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl,
                transferable: true
            })
        );

        // Mint tokens at different times
        vm.prank(minter);
        v1.mint(alice, tokenId, 50);

        vm.warp(block.timestamp + 3600); // 1 hour later
        vm.prank(minter);
        v1.mint(alice, tokenId, 75);

        // Check balance records
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
        assertEq(records.length, 2);
        assertEq(v1.balanceOf(alice, tokenId), 125);
    }

    function test_ephemeralToken_pruning() public {
        // Create token with short TTL
        uint256 ttl = 60; // 1 minute
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl,
                transferable: true
            })
        );

        // Mint tokens
        vm.prank(minter);
        v1.mint(alice, tokenId, 100);
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Let tokens expire
        vm.warp(block.timestamp + ttl * 2);
        assertEq(v1.balanceOf(alice, tokenId), 0);

        // Prune expired records
        v1.pruneBalanceRecords(alice, tokenId);

        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
        assertEq(records.length, 0);
    }

    // ============ Transfer Mechanisms Tests ============= //

    function testRevert_transfer_TokenIsNonTransferable() public {
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: false // Non-transferable
             })
        );

        vm.prank(minter);
        v1.mint(alice, tokenId, 100);

        vm.expectRevert(abi.encodeWithSelector(TokenTransferable.TokenIsNonTransferable.selector, tokenId));
        vm.prank(alice);
        v1.transfer(bob, tokenId, 50);

        assertEq(v1.balanceOf(alice, tokenId), 100);
        assertEq(v1.balanceOf(bob, tokenId), 0);
    }

    function testRevert_transfer_AccountFrozen() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        vm.prank(accessManager);
        v1.freezeAccount(alice);

        vm.expectRevert(abi.encodeWithSelector(AccountFreezable.AccountFrozen.selector, alice));
        vm.prank(alice);
        v1.transfer(bob, tokenId, 50);
    }

    function testRevert_transfer_EnforcedPause() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        // Pause the contract
        vm.prank(accessManager);
        v1.pause();

        vm.expectRevert();
        vm.prank(alice);
        v1.transfer(bob, tokenId, 50);
    }

    function testRevert_transferFrom_InsufficientAllowance() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        // Bob tries to transfer without allowance
        vm.expectRevert();
        vm.prank(bob);
        v1.transferFrom(alice, carol, tokenId, 50);
    }

    function test_transferFrom_partialAllowance() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        // Alice approves Bob for 30 tokens
        vm.prank(alice);
        v1.approve(bob, tokenId, 30);

        // Bob transfers 20 tokens
        vm.prank(bob);
        v1.transferFrom(alice, carol, tokenId, 20);

        assertEq(v1.balanceOf(alice, tokenId), 80);
        assertEq(v1.balanceOf(carol, tokenId), 20);
        assertEq(v1.allowance(alice, bob, tokenId), 10); // Remaining allowance
    }

    function testRevert_transfer_InvalidSelfTransfer() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        vm.expectRevert(abi.encodeWithSelector(EVMAuth.InvalidSelfTransfer.selector, alice));
        vm.prank(alice);
        v1.transfer(alice, tokenId, 50);
    }

    function testRevert_transfer_InvalidZeroValueTransfer() public {
        uint256 tokenId = _createAndMintToken(alice, 100);

        vm.expectRevert(abi.encodeWithSelector(EVMAuth.InvalidZeroValueTransfer.selector));
        vm.prank(alice);
        v1.transfer(bob, tokenId, 0);
    }

    // ============ Metadata Management Tests ============= //

    function test_setContractURI() public {
        string memory newURI = "https://new-domain.com/metadata.json";

        vm.prank(tokenManager);
        v1.setContractURI(newURI);

        assertEq(v1.contractURI(), newURI);
    }

    function testRevert_setContractURI_AccessControlUnauthorizedAccount() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, v1.TOKEN_MANAGER_ROLE()
            )
        );
        vm.prank(alice);
        v1.setContractURI("https://unauthorized.com/metadata.json");
    }

    function test_setTokenURI() public {
        uint256 tokenId = _createPurchasableToken(1 ether);
        string memory tokenURI = "https://token-metadata.com/1.json";

        vm.prank(tokenManager);
        v1.setTokenURI(tokenId, tokenURI);
    }

    function test_setTokenMetadata() public {
        uint256 tokenId = _createPurchasableToken(1 ether);

        vm.prank(tokenManager);
        v1.setTokenMetadata(tokenId, "Access Token", "ACCESS", 0);

        assertEq(v1.name(tokenId), "Access Token");
        assertEq(v1.symbol(tokenId), "ACCESS");
        assertEq(v1.decimals(tokenId), 0);
    }

    function testRevert_setTokenMetadata_AccessControlUnauthorizedAccount() public {
        uint256 tokenId = _createPurchasableToken(1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, v1.TOKEN_MANAGER_ROLE()
            )
        );
        vm.prank(alice);
        v1.setTokenMetadata(tokenId, "Unauthorized", "UNAUTH", 0);
    }

    // ============ Access Control Integration Tests ============= //

    function test_pause_unpause() public {
        // Pause contract
        vm.prank(accessManager);
        v1.pause();
        assertTrue(v1.paused());

        // Unpause contract
        vm.prank(accessManager);
        v1.unpause();
        assertFalse(v1.paused());
    }

    function test_freezeAccount_unfreezeAccount() public {
        // Freeze Alice's account
        vm.expectEmit(true, true, false, true);
        emit AccountFreezable.AccountStatusUpdated(alice, v1.ACCOUNT_FROZEN_STATUS());

        vm.prank(accessManager);
        v1.freezeAccount(alice);
        assertTrue(v1.isFrozen(alice));

        // Unfreeze Alice's account
        vm.expectEmit(true, true, false, true);
        emit AccountFreezable.AccountStatusUpdated(alice, v1.ACCOUNT_UNFROZEN_STATUS());

        vm.prank(accessManager);
        v1.unfreezeAccount(alice);
        assertFalse(v1.isFrozen(alice));
    }

    function test_setTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectEmit(false, true, false, true);
        emit TokenPurchasable.TreasuryUpdated(treasurer, newTreasury);

        vm.prank(treasurer);
        v1.setTreasury(newTreasury);

        assertEq(v1.treasury(), newTreasury);
    }

    function testRevert_setTreasury_AccessControlUnauthorizedAccount() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, v1.TREASURER_ROLE())
        );
        vm.prank(alice);
        v1.setTreasury(newTreasury);
    }

    function test_supportsInterface() public view {
        // Test that the contract supports required interfaces
        bytes4 erc6909InterfaceId = 0x0f632fb3; // IERC6909
        bytes4 erc165InterfaceId = 0x01ffc9a7; // IERC165
        bytes4 accessControlInterfaceId = 0x7965db0b; // IAccessControl

        assertTrue(v1.supportsInterface(erc6909InterfaceId), "Should support IERC6909");
        assertTrue(v1.supportsInterface(erc165InterfaceId), "Should support IERC165");
        assertTrue(v1.supportsInterface(accessControlInterfaceId), "Should support IAccessControl");
    }

    // ============ Helper Functions ============= //

    function _createPurchasableToken(uint256 price) internal returns (uint256) {
        vm.prank(tokenManager);
        return v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: price,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0, // Permanent
                transferable: true
            })
        );
    }

    function _createAndMintToken(address to, uint256 amount) internal returns (uint256) {
        uint256 tokenId = _createPurchasableToken(1 ether);
        vm.prank(minter);
        v1.mint(to, tokenId, amount);
        return tokenId;
    }
}
