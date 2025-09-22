// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { BaseTestWithAccessControlAndERC20s } from "test/_helpers/BaseTest.sol";

contract EVMAuth1155Test is BaseTestWithAccessControlAndERC20s {
    EVMAuth1155 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new EVMAuth1155());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth1155.sol:EVMAuth1155";
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
            EVMAuth1155.initialize, (2 days, owner, treasury, roleGrants, "https://token-cdn-domain/{id}.json")
        );
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = EVMAuth1155(proxyAddress);
    }

    function _grantRoles() internal override {
        // Roles are granted during initialization
    }

    // ============ Tests ============= //

    // Events for testing
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    event EVMAuthTokenConfigured(uint256 indexed id, EVMAuth.EVMAuthTokenConfig config);
    event TokenPurchased(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 price);
    event AccountStatusUpdated(address indexed account, bytes32 indexed status);

    function test_initialize() public view {
        assertEq(v1.nextTokenID(), 1);
        assertEq(v1.uri(1), "https://token-cdn-domain/{id}.json");

        assertTrue(v1.hasRole(v1.UPGRADE_MANAGER_ROLE(), owner), "Upgrade manager role not set correctly");
        assertTrue(v1.hasRole(v1.ACCESS_MANAGER_ROLE(), accessManager), "Access manager role not set correctly");
        assertTrue(v1.hasRole(v1.TOKEN_MANAGER_ROLE(), tokenManager), "Token manager role not set correctly");
        assertTrue(v1.hasRole(v1.MINTER_ROLE(), minter), "Minter role not set correctly");
        assertTrue(v1.hasRole(v1.BURNER_ROLE(), burner), "Burner role not set correctly");
        assertTrue(v1.hasRole(v1.TREASURER_ROLE(), treasurer), "Treasurer role not set correctly");
    }

    // ============ ERC1155 Standard Compliance Tests ============= //

    function test_mint_singleToken() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Create token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Expect TransferSingle event
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(minter, address(0), alice, tokenId, amount);

        // Mint tokens
        vm.prank(minter);
        v1.mint(alice, tokenId, amount, "");

        // Verify balance
        assertEq(v1.balanceOf(alice, tokenId), amount);
    }

    function test_mintBatch_multipleTokens() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        amounts[0] = 100;
        amounts[1] = 50;

        // Create tokens first
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0,
            transferable: true
        });

        vm.startPrank(tokenManager);
        v1.createToken(config);
        v1.createToken(config);
        vm.stopPrank();

        // Expect TransferBatch event
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(minter, address(0), alice, tokenIds, amounts);

        // Batch mint tokens
        vm.prank(minter);
        v1.mintBatch(alice, tokenIds, amounts, "");

        // Verify balances
        assertEq(v1.balanceOf(alice, tokenIds[0]), amounts[0]);
        assertEq(v1.balanceOf(alice, tokenIds[1]), amounts[1]);
    }

    function testRevert_mint_unauthorizedAccount() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Create token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Attempt to mint without MINTER_ROLE
        vm.expectRevert();
        vm.prank(alice);
        v1.mint(alice, tokenId, amount, "");
    }

    function test_burn_singleToken() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Create and mint token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        vm.prank(minter);
        v1.mint(alice, tokenId, amount, "");

        // Expect TransferSingle event for burn
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(burner, alice, address(0), tokenId, amount);

        // Burn tokens
        vm.prank(burner);
        v1.burn(alice, tokenId, amount);

        // Verify balance is zero
        assertEq(v1.balanceOf(alice, tokenId), 0);
    }

    function test_burnBatch_multipleTokens() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        amounts[0] = 100;
        amounts[1] = 50;

        // Create and mint tokens first
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0,
            transferable: true
        });

        vm.startPrank(tokenManager);
        v1.createToken(config);
        v1.createToken(config);
        vm.stopPrank();

        vm.prank(minter);
        v1.mintBatch(alice, tokenIds, amounts, "");

        // Expect TransferBatch event for burn
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(burner, alice, address(0), tokenIds, amounts);

        // Batch burn tokens
        vm.prank(burner);
        v1.burnBatch(alice, tokenIds, amounts);

        // Verify balances are zero
        assertEq(v1.balanceOf(alice, tokenIds[0]), 0);
        assertEq(v1.balanceOf(alice, tokenIds[1]), 0);
    }

    function testRevert_burn_unauthorizedAccount() public {
        uint256 tokenId = 1;
        uint256 amount = 100;

        // Create and mint token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        vm.prank(minter);
        v1.mint(alice, tokenId, amount, "");

        // Attempt to burn without BURNER_ROLE
        vm.expectRevert();
        vm.prank(alice);
        v1.burn(alice, tokenId, amount);
    }

    function test_safeTransferFrom_singleToken() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        uint256 transferAmount = 30;

        // Create and mint token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        vm.prank(minter);
        v1.mint(alice, tokenId, amount, "");

        // Expect TransferSingle event
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, tokenId, transferAmount);

        // Transfer tokens
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, transferAmount, "");

        // Verify balances
        assertEq(v1.balanceOf(alice, tokenId), amount - transferAmount);
        assertEq(v1.balanceOf(bob, tokenId), transferAmount);
    }

    function test_safeBatchTransferFrom_multipleTokens() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        amounts[0] = 100;
        amounts[1] = 50;
        transferAmounts[0] = 30;
        transferAmounts[1] = 20;

        // Create and mint tokens first
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0,
            transferable: true
        });

        vm.startPrank(tokenManager);
        v1.createToken(config);
        v1.createToken(config);
        vm.stopPrank();

        vm.prank(minter);
        v1.mintBatch(alice, tokenIds, amounts, "");

        // Expect TransferBatch event
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, tokenIds, transferAmounts);

        // Batch transfer tokens
        vm.prank(alice);
        v1.safeBatchTransferFrom(alice, bob, tokenIds, transferAmounts, "");

        // Verify balances
        assertEq(v1.balanceOf(alice, tokenIds[0]), amounts[0] - transferAmounts[0]);
        assertEq(v1.balanceOf(alice, tokenIds[1]), amounts[1] - transferAmounts[1]);
        assertEq(v1.balanceOf(bob, tokenIds[0]), transferAmounts[0]);
        assertEq(v1.balanceOf(bob, tokenIds[1]), transferAmounts[1]);
    }

    function test_setApprovalForAll() public {
        // Expect ApprovalForAll event
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);

        // Set approval
        vm.prank(alice);
        v1.setApprovalForAll(bob, true);

        // Verify approval
        assertTrue(v1.isApprovedForAll(alice, bob));

        // Remove approval
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, false);

        vm.prank(alice);
        v1.setApprovalForAll(bob, false);

        // Verify approval removed
        assertFalse(v1.isApprovedForAll(alice, bob));
    }

    function test_balanceOfBatch() public {
        uint256[] memory tokenIds = new uint256[](3);
        address[] memory accounts = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 1;
        accounts[0] = alice;
        accounts[1] = alice;
        accounts[2] = bob;
        amounts[0] = 100;
        amounts[1] = 50;
        amounts[2] = 25;

        // Create tokens and mint
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0,
            transferable: true
        });

        vm.startPrank(tokenManager);
        v1.createToken(config);
        v1.createToken(config);
        vm.stopPrank();

        vm.startPrank(minter);
        v1.mint(alice, tokenIds[0], amounts[0], "");
        v1.mint(alice, tokenIds[1], amounts[1], "");
        v1.mint(bob, tokenIds[2], amounts[2], "");
        vm.stopPrank();

        // Get batch balances
        uint256[] memory balances = v1.balanceOfBatch(accounts, tokenIds);

        // Verify balances
        assertEq(balances[0], amounts[0]);
        assertEq(balances[1], amounts[1]);
        assertEq(balances[2], amounts[2]);
    }

    function test_setBaseURI() public {
        string memory newBaseURI = "https://new-cdn-domain";

        // Create token first
        vm.startPrank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );
        // Base URI is only ever used if both base- and token URI are set
        v1.setTokenURI(1, "/token1.json");
        // Set new base URI
        v1.setBaseURI(newBaseURI);
        vm.stopPrank();

        // Verify URI for token uses new base
        assertEq(v1.uri(1), "https://new-cdn-domain/token1.json");
    }

    function test_setTokenURI() public {
        uint256 tokenId = 1;
        string memory customURI = "https://custom-uri.com/token1.json";

        // Create token first
        vm.prank(tokenManager);
        v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Expect URI event
        vm.expectEmit(false, true, false, true);
        emit URI(customURI, tokenId);

        // Set custom URI for specific token
        vm.prank(tokenManager);
        v1.setTokenURI(tokenId, customURI);

        // Verify custom URI
        assertEq(v1.uri(tokenId), customURI);

        // Verify other tokens still use base URI
        assertEq(v1.uri(999), "https://token-cdn-domain/{id}.json");
    }

    function testRevert_setBaseURI_unauthorizedAccount() public {
        vm.expectRevert();
        vm.prank(alice);
        v1.setBaseURI("https://unauthorized.com/{id}.json");
    }

    function testRevert_setTokenURI_unauthorizedAccount() public {
        vm.expectRevert();
        vm.prank(alice);
        v1.setTokenURI(1, "https://unauthorized.com/token1.json");
    }

    // ============ Token Creation & Management Tests ============= //

    function test_createToken_permanent() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0, // Permanent
            transferable: true
        });

        // Expect token configured event
        vm.expectEmit(true, false, false, true);
        emit EVMAuthTokenConfigured(1, config);

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        // Verify token configuration
        assertEq(tokenId, 1);
        assertTrue(v1.exists(tokenId));
        assertEq(v1.tokenPrice(tokenId), 1 ether);
        assertEq(v1.tokenTTL(tokenId), 0);
        assertTrue(v1.isTransferable(tokenId));
    }

    function test_createToken_ephemeral() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 0.5 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600, // 1 hour
            transferable: false
        });

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        // Verify token configuration
        assertEq(tokenId, 1);
        assertTrue(v1.exists(tokenId));
        assertEq(v1.tokenPrice(tokenId), 0.5 ether);
        assertEq(v1.tokenTTL(tokenId), 3600);
        assertFalse(v1.isTransferable(tokenId));
    }

    function test_createToken_withERC20Prices() public {
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](2);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: 100e18 });
        erc20Prices[1] = TokenPurchasable.PaymentToken({ token: address(usdt), price: 50e6 });

        EVMAuth.EVMAuthTokenConfig memory config =
            EVMAuth.EVMAuthTokenConfig({ price: 0, erc20Prices: erc20Prices, ttl: 0, transferable: true });

        // Create token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(config);

        // Verify ERC20 prices
        TokenPurchasable.PaymentToken[] memory prices = v1.tokenERC20Prices(tokenId);
        assertEq(prices.length, 2);
        assertEq(prices[0].token, address(usdc));
        assertEq(prices[0].price, 100e18);
        assertEq(prices[1].token, address(usdt));
        assertEq(prices[1].price, 50e6);
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

        // Create tokens
        vm.startPrank(tokenManager);
        uint256 tokenId1 = v1.createToken(config1);
        uint256 tokenId2 = v1.createToken(config2);
        vm.stopPrank();

        // Verify token IDs and next token ID
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(v1.nextTokenID(), 3);

        // Verify configurations
        assertEq(v1.tokenPrice(tokenId1), 1 ether);
        assertEq(v1.tokenTTL(tokenId1), 3600);
        assertTrue(v1.isTransferable(tokenId1));

        assertEq(v1.tokenPrice(tokenId2), 2 ether);
        assertEq(v1.tokenTTL(tokenId2), 7200);
        assertFalse(v1.isTransferable(tokenId2));
    }

    function test_updateTokenConfig() public {
        // Create initial token
        EVMAuth.EVMAuthTokenConfig memory initialConfig = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: true
        });

        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(initialConfig);

        // Update configuration
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 7200,
            transferable: false
        });

        vm.expectEmit(true, false, false, true);
        emit EVMAuthTokenConfigured(tokenId, newConfig);

        vm.prank(tokenManager);
        v1.updateToken(tokenId, newConfig);

        // Verify updated configuration
        assertEq(v1.tokenPrice(tokenId), 2 ether);
        assertEq(v1.tokenTTL(tokenId), 7200);
        assertFalse(v1.isTransferable(tokenId));
    }

    function test_exists() public {
        // Initially no tokens exist
        assertFalse(v1.exists(1));
        assertFalse(v1.exists(999));

        // Create a token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Token should now exist
        assertTrue(v1.exists(tokenId));

        // Other tokens should still not exist
        assertFalse(v1.exists(tokenId + 1));
        assertFalse(v1.exists(999));
    }

    function testRevert_createToken_unauthorizedAccount() public {
        EVMAuth.EVMAuthTokenConfig memory config = EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 0,
            transferable: true
        });

        vm.expectRevert();
        vm.prank(alice);
        v1.createToken(config);
    }

    function testRevert_updateTokenConfig_unauthorizedAccount() public {
        // Create token first
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 1 ether,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Try to update without permission
        EVMAuth.EVMAuthTokenConfig memory newConfig = EVMAuth.EVMAuthTokenConfig({
            price: 2 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: 3600,
            transferable: false
        });

        vm.expectRevert();
        vm.prank(alice);
        v1.updateToken(tokenId, newConfig);
    }

    // ============ Purchase Integration Tests ============= //

    function test_purchase_withNativeCurrency() public {
        uint256 price = 1 ether;
        uint256 amount = 5;
        uint256 totalCost = price * amount;

        // Create purchasable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: price,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Give alice some ETH
        vm.deal(alice, 10 ether);

        // Record initial treasury balance
        uint256 initialTreasuryBalance = treasury.balance;

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, address(0), alice, tokenId, amount);

        vm.expectEmit(false, true, true, true);
        emit TokenPurchased(alice, alice, tokenId, amount, totalCost);

        // Purchase tokens
        vm.prank(alice);
        v1.purchase{ value: totalCost }(tokenId, amount);

        // Verify token balance
        assertEq(v1.balanceOf(alice, tokenId), amount);

        // Verify treasury received payment
        assertEq(treasury.balance, initialTreasuryBalance + totalCost);

        // Verify alice's ETH was deducted
        assertEq(alice.balance, 10 ether - totalCost);
    }

    function test_purchase_withERC20() public {
        uint256 price = 100e18;
        uint256 amount = 3;
        uint256 totalCost = price * amount;

        // Setup ERC20 payment
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: price });

        // Create purchasable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0, // No native currency price
                erc20Prices: erc20Prices,
                ttl: 0,
                transferable: true
            })
        );

        // Give alice USDC and approve spending
        usdc.mint(alice, 1000e18);
        vm.prank(alice);
        usdc.approve(address(v1), totalCost);

        // Record initial treasury balance
        uint256 initialTreasuryBalance = usdc.balanceOf(treasury);

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, address(0), alice, tokenId, amount);

        vm.expectEmit(false, true, true, true);
        emit TokenPurchased(alice, alice, tokenId, amount, totalCost);

        // Purchase tokens with ERC20
        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, amount);

        // Verify token balance
        assertEq(v1.balanceOf(alice, tokenId), amount);

        // Verify treasury received payment
        assertEq(usdc.balanceOf(treasury), initialTreasuryBalance + totalCost);

        // Verify alice's USDC was deducted
        assertEq(usdc.balanceOf(alice), 1000e18 - totalCost);
    }

    function test_purchaseFor() public {
        uint256 price = 0.5 ether;
        uint256 amount = 2;
        uint256 totalCost = price * amount;

        // Create purchasable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: price,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Give alice some ETH
        vm.deal(alice, 10 ether);

        // Expect events - tokens minted to bob, but purchased by alice
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, address(0), bob, tokenId, amount);

        vm.expectEmit(false, true, true, true);
        emit TokenPurchased(alice, bob, tokenId, amount, totalCost);

        // Alice purchases tokens for bob
        vm.prank(alice);
        v1.purchaseFor{ value: totalCost }(bob, tokenId, amount);

        // Verify bob received tokens
        assertEq(v1.balanceOf(bob, tokenId), amount);
        assertEq(v1.balanceOf(alice, tokenId), 0);
    }

    function testRevert_purchase_insufficientPayment() public {
        uint256 price = 1 ether;
        uint256 amount = 5;
        uint256 totalCost = price * amount;
        uint256 insufficientPayment = totalCost - 0.1 ether;

        // Create purchasable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: price,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Give alice some ETH
        vm.deal(alice, 10 ether);

        // Attempt purchase with insufficient payment
        vm.expectRevert();
        vm.prank(alice);
        v1.purchase{ value: insufficientPayment }(tokenId, amount);
    }

    function testRevert_purchaseWithERC20_insufficientAllowance() public {
        uint256 price = 100e18;
        uint256 amount = 3;
        uint256 totalCost = price * amount;
        uint256 insufficientAllowance = totalCost - 10e18;

        // Setup ERC20 payment
        TokenPurchasable.PaymentToken[] memory erc20Prices = new TokenPurchasable.PaymentToken[](1);
        erc20Prices[0] = TokenPurchasable.PaymentToken({ token: address(usdc), price: price });

        // Create purchasable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({ price: 0, erc20Prices: erc20Prices, ttl: 0, transferable: true })
        );

        // Give alice USDC but approve insufficient amount
        usdc.mint(alice, 1000e18);
        vm.prank(alice);
        usdc.approve(address(v1), insufficientAllowance);

        // Attempt purchase with insufficient allowance
        vm.expectRevert();
        vm.prank(alice);
        v1.purchaseWithERC20(address(usdc), tokenId, amount);
    }

    // ============ Ephemeral Token Behavior Tests ============= //

    function test_ephemeralToken_expiration() public {
        uint48 ttl = 3600; // 1 hour
        uint256 bucketSize = ttl / 100; // DEFAULT_MAX_BALANCE_RECORDS = 100

        // Create ephemeral token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: ttl,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Initially alice should have full balance
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Fast forward time a bit - tokens should still be valid
        vm.warp(block.timestamp + bucketSize);
        assertEq(v1.balanceOf(alice, tokenId), 100);

        // Fast forward past expiration - tokens should be expired
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
        v1.mint(alice, tokenId1, 50, "");
        v1.mint(alice, tokenId2, 100, "");
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
        v1.mint(alice, tokenId, 100, "");

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
        v1.mint(alice, tokenId, 50, "");

        vm.warp(block.timestamp + 3600); // 1 hour later
        vm.prank(minter);
        v1.mint(alice, tokenId, 75, "");

        // Check balance records
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
        assertEq(records.length, 2);
        assertEq(v1.balanceOf(alice, tokenId), 125);
    }

    function test_ephemeralToken_pruning() public {
        // Create ephemeral token
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
        v1.mint(alice, tokenId, 5, "");
        assertEq(v1.balanceOf(alice, tokenId), 5);

        // Let tokens expire
        vm.warp(block.timestamp + ttl * 2);
        assertEq(v1.balanceOf(alice, tokenId), 0);

        // Prune expired records
        v1.pruneBalanceRecords(alice, tokenId);

        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
        assertEq(records.length, 0);
    }

    // ============ Transfer Restrictions Tests ============= //

    function testRevert_transfer_TokenIsNonTransferable() public {
        // Create non-transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: false
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Attempt transfer should revert
        vm.expectRevert();
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 50, "");

        // Verify alice still has all tokens
        assertEq(v1.balanceOf(alice, tokenId), 100);
        assertEq(v1.balanceOf(bob, tokenId), 0);
    }

    function test_transfer_transferableToken() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Transfer should succeed
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 50, "");

        // Verify balances updated
        assertEq(v1.balanceOf(alice, tokenId), 50);
        assertEq(v1.balanceOf(bob, tokenId), 50);
    }

    function testRevert_transfer_AccountFrozen() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Freeze alice's account
        vm.prank(accessManager);
        v1.freezeAccount(alice);

        // Transfer should revert due to frozen account
        vm.expectRevert();
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 50, "");

        // Verify balances unchanged
        assertEq(v1.balanceOf(alice, tokenId), 100);
        assertEq(v1.balanceOf(bob, tokenId), 0);
    }

    function test_transfer_whenPaused_thenWhenUnpaused() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Pause the contract
        vm.prank(accessManager);
        v1.pause();

        // Transfer should revert when paused
        vm.expectRevert();
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 50, "");

        // Unpause and try again
        vm.prank(accessManager);
        v1.unpause();

        // Transfer should now succeed
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 50, "");

        // Verify balances updated
        assertEq(v1.balanceOf(alice, tokenId), 50);
        assertEq(v1.balanceOf(bob, tokenId), 50);
    }

    function testRevert_transfer_selfTransfer() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Self-transfer should revert
        vm.expectRevert();
        vm.prank(alice);
        v1.safeTransferFrom(alice, alice, tokenId, 50, "");
    }

    function testRevert_transfer_zeroAmount() public {
        // Create transferable token
        vm.prank(tokenManager);
        uint256 tokenId = v1.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: 0,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: 0,
                transferable: true
            })
        );

        // Mint tokens to alice
        vm.prank(minter);
        v1.mint(alice, tokenId, 100, "");

        // Zero amount transfer should revert
        vm.expectRevert();
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, 0, "");
    }

    // ============ Access Control Integration Tests ============= //

    function test_pause_unpause() public {
        // Initially not paused
        assertFalse(v1.paused());

        // Pause the contract
        vm.prank(accessManager);
        v1.pause();
        assertTrue(v1.paused());

        // Unpause the contract
        vm.prank(accessManager);
        v1.unpause();
        assertFalse(v1.paused());
    }

    function testRevert_pause_unauthorizedAccount() public {
        vm.expectRevert();
        vm.prank(alice);
        v1.pause();
    }

    function testRevert_unpause_unauthorizedAccount() public {
        // Pause first
        vm.prank(accessManager);
        v1.pause();

        // Try to unpause with unauthorized account
        vm.expectRevert();
        vm.prank(alice);
        v1.unpause();
    }

    function test_freezeAccount_unfreezeAccount() public {
        // Initially not frozen
        assertFalse(v1.isFrozen(alice));

        // Expect freeze event
        vm.expectEmit(true, true, false, false);
        emit AccountStatusUpdated(alice, v1.ACCOUNT_FROZEN_STATUS());

        // Freeze account
        vm.prank(accessManager);
        v1.freezeAccount(alice);
        assertTrue(v1.isFrozen(alice));

        // Expect unfreeze event
        vm.expectEmit(true, true, false, false);
        emit AccountStatusUpdated(alice, v1.ACCOUNT_UNFROZEN_STATUS());

        // Unfreeze account
        vm.prank(accessManager);
        v1.unfreezeAccount(alice);
        assertFalse(v1.isFrozen(alice));
    }

    function testRevert_freezeAccount_unauthorizedAccount() public {
        vm.expectRevert();
        vm.prank(alice);
        v1.freezeAccount(bob);
    }

    function testRevert_unfreezeAccount_unauthorizedAccount() public {
        // Freeze first
        vm.prank(accessManager);
        v1.freezeAccount(alice);

        // Try to unfreeze with unauthorized account
        vm.expectRevert();
        vm.prank(bob);
        v1.unfreezeAccount(alice);
    }

    function testRevert_mintBatch_unauthorizedAccount() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 1;
        amounts[0] = 100;

        vm.expectRevert();
        vm.prank(alice);
        v1.mintBatch(alice, ids, amounts, "");
    }

    function testRevert_burnBatch_unauthorizedAccount() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 1;
        amounts[0] = 100;

        vm.expectRevert();
        vm.prank(alice);
        v1.burnBatch(alice, ids, amounts);
    }

    function test_supportsInterface() public view {
        // Test that the contract supports required interfaces
        bytes4 erc1155InterfaceId = 0xd9b67a26;
        bytes4 erc1155MetadataInterfaceId = 0x0e89341c;
        bytes4 accessControlInterfaceId = 0x7965db0b;

        assertTrue(v1.supportsInterface(erc1155InterfaceId));
        assertTrue(v1.supportsInterface(erc1155MetadataInterfaceId));
        assertTrue(v1.supportsInterface(accessControlInterfaceId));
    }
}
