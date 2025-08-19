// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155AccessControl} from "src/ERC1155/IERC1155AccessControl.sol";
import {ERC1155AccessControl} from "src/ERC1155/ERC1155AccessControl.sol";
import {ERC1155Base} from "src/ERC1155/extensions/ERC1155Base.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract ERC1155AccessControlTest is Test {
    ERC1155AccessControl public token;

    address public defaultAdmin;
    address public accessManager;
    address public tokenManager;
    address public minter;
    address public burner;
    address public treasurer;
    address payable public treasury;
    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TOKEN_ID_3 = 3;

    uint48 public constant INITIAL_DELAY = 3 days;
    string public constant INITIAL_URI = "https://example.com/api/token/{id}.json";

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    // Events
    event URI(string value, uint256 indexed id);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event DefaultAdminTransferScheduled(address indexed newAdmin, uint48 acceptSchedule);
    event DefaultAdminTransferCanceled();
    event DefaultAdminDelayChangeScheduled(uint48 newDelay, uint48 effectSchedule);
    event DefaultAdminDelayChangeCanceled();
    event ERC1155PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC1155PriceSuspended(address caller, uint256 indexed id);
    event ERC1155NonTransferableUpdated(uint256 indexed id, bool nonTransferable);
    event ERC1155TTLUpdated(address caller, uint256 indexed id, uint256 ttl);
    event TreasuryUpdated(address caller, address indexed account);
    event AccountStatusUpdate(address indexed account, bytes32 indexed status);
    event Paused(address account);
    event Unpaused(address account);

    // Helper function to set TTL for a token (required before minting with ERC1155TTL)
    function _setTokenTTL(uint256 tokenId, uint256 ttl) internal {
        vm.prank(tokenManager);
        token.setTTL(tokenId, ttl);
    }

    function setUp() public {
        defaultAdmin = makeAddr("defaultAdmin");
        tokenManager = makeAddr("tokenManager");
        minter = makeAddr("tokenMinter");
        burner = makeAddr("tokenBurner");
        accessManager = makeAddr("accessManager");
        treasurer = makeAddr("treasurer");
        treasury = payable(makeAddr("treasury"));
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(treasurer, 100 ether);

        vm.prank(defaultAdmin);
        token = new ERC1155AccessControl(INITIAL_DELAY, defaultAdmin, treasury, INITIAL_URI);

        // Grant roles
        vm.startPrank(defaultAdmin);
        token.grantRole(TOKEN_MANAGER_ROLE, tokenManager);
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(BURNER_ROLE, burner);
        token.grantRole(TREASURER_ROLE, treasurer);
        token.grantRole(ACCESS_MANAGER_ROLE, accessManager);
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(token.defaultAdmin(), defaultAdmin);
        assertEq(token.defaultAdminDelay(), INITIAL_DELAY);
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertEq(token.treasury(), treasury);
        assertEq(token.uri(0), INITIAL_URI);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155MetadataURI).interfaceId));
    }

    function test_roles() public view {
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertTrue(token.hasRole(ACCESS_MANAGER_ROLE, accessManager));
        assertTrue(token.hasRole(TOKEN_MANAGER_ROLE, tokenManager));
        assertTrue(token.hasRole(MINTER_ROLE, minter));
        assertTrue(token.hasRole(BURNER_ROLE, burner));
        assertTrue(token.hasRole(TREASURER_ROLE, treasurer));

        assertFalse(token.hasRole(DEFAULT_ADMIN_ROLE, alice));
        assertFalse(token.hasRole(ACCESS_MANAGER_ROLE, alice));
        assertFalse(token.hasRole(TOKEN_MANAGER_ROLE, alice));
        assertFalse(token.hasRole(MINTER_ROLE, alice));
        assertFalse(token.hasRole(BURNER_ROLE, alice));
        assertFalse(token.hasRole(TREASURER_ROLE, alice));
    }

    function test_setURI() public {
        string memory uri = "https://example.com/metadata/";

        vm.prank(tokenManager);
        token.setURI(uri);

        assertEq(token.uri(0), uri);
        assertEq(token.uri(TOKEN_ID_1), uri);
    }

    function test_setURI_unauthorized() public {
        string memory uri = "https://example.com/metadata/";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setURI(uri);
    }

    function test_setTokenURI() public {
        string memory uri = "https://example.com/token/1.json";

        vm.expectEmit(true, true, false, true);
        emit URI(uri, TOKEN_ID_1);

        vm.prank(tokenManager);
        token.setTokenURI(TOKEN_ID_1, uri);

        assertEq(token.uri(TOKEN_ID_1), uri);
    }

    function test_setTokenURI_unauthorized() public {
        string memory uri = "https://example.com/token/1.json";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTokenURI(TOKEN_ID_1, uri);
    }

    function test_mint() public {
        uint256 amount = 1000;

        // Set TTL first (required by ERC1155TTL)
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(minter, address(0), alice, TOKEN_ID_1, amount);

        vm.prank(minter);
        bool success = token.mint(alice, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(token.totalSupply(TOKEN_ID_1), amount);
        assertTrue(token.exists(TOKEN_ID_1));
    }

    function test_mintBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;

        // Set TTL for all tokens first
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(minter, address(0), alice, ids, amounts);

        vm.prank(minter);
        bool success = token.mintBatch(alice, ids, amounts);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1]);
        assertEq(token.totalSupply(TOKEN_ID_1), amounts[0]);
        assertEq(token.totalSupply(TOKEN_ID_2), amounts[1]);
        assertTrue(token.exists(TOKEN_ID_1));
        assertTrue(token.exists(TOKEN_ID_2));
    }

    function test_mint_multipleTokenTypes() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 2000;
        uint256 amount3 = 3000;

        // Set TTL for all tokens first
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        token.setTTL(TOKEN_ID_3, 0); // Non-expiring
        vm.stopPrank();

        vm.startPrank(minter);
        assertTrue(token.mint(alice, TOKEN_ID_1, amount1));
        assertTrue(token.mint(alice, TOKEN_ID_2, amount2));
        assertTrue(token.mint(bob, TOKEN_ID_3, amount3));
        vm.stopPrank();

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount1);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amount2);
        assertEq(token.balanceOf(bob, TOKEN_ID_3), amount3);

        assertEq(token.totalSupply(TOKEN_ID_1), amount1);
        assertEq(token.totalSupply(TOKEN_ID_2), amount2);
        assertEq(token.totalSupply(TOKEN_ID_3), amount3);
    }

    function test_mint_unauthorized() public {
        uint256 amount = 1000;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, MINTER_ROLE)
        );
        vm.prank(alice);
        token.mint(alice, TOKEN_ID_1, amount);
    }

    function test_mintBatch_unauthorized() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, MINTER_ROLE)
        );
        vm.prank(alice);
        token.mintBatch(alice, ids, amounts);
    }

    function test_burn() public {
        uint256 mintAmount = 1000;
        uint256 burnAmount = 400;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // First mint some tokens
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, mintAmount);

        // Then burn some
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(burner, alice, address(0), TOKEN_ID_1, burnAmount);

        vm.prank(burner);
        bool success = token.burn(alice, TOKEN_ID_1, burnAmount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmount - burnAmount);
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmount - burnAmount);
    }

    function test_burnBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory mintAmounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        mintAmounts[0] = 1000;
        mintAmounts[1] = 2000;
        burnAmounts[0] = 400;
        burnAmounts[1] = 800;

        // Set TTL for all tokens first
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        vm.stopPrank();

        // First mint some tokens
        vm.prank(minter);
        token.mintBatch(alice, ids, mintAmounts);

        // Then burn some
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(burner, alice, address(0), ids, burnAmounts);

        vm.prank(burner);
        bool success = token.burnBatch(alice, ids, burnAmounts);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmounts[0] - burnAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), mintAmounts[1] - burnAmounts[1]);
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmounts[0] - burnAmounts[0]);
        assertEq(token.totalSupply(TOKEN_ID_2), mintAmounts[1] - burnAmounts[1]);
    }

    function test_burn_entireBalance() public {
        uint256 amount = 1000;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // First mint some tokens
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Then burn all
        vm.prank(burner);
        bool success = token.burn(alice, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.totalSupply(TOKEN_ID_1), 0);
        assertFalse(token.exists(TOKEN_ID_1)); // Should not exist after burning all
    }

    function test_burn_unauthorized() public {
        uint256 amount = 1000;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // First mint some tokens
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Try to burn without permission
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, BURNER_ROLE)
        );
        vm.prank(alice);
        token.burn(alice, TOKEN_ID_1, amount);
    }

    function test_burnBatch_unauthorized() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, BURNER_ROLE)
        );
        vm.prank(alice);
        token.burnBatch(alice, ids, amounts);
    }

    function test_safeTransferFrom() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint tokens to alice
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice transfers to bob
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, transferAmount);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, transferAmount, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
        assertEq(token.totalSupply(TOKEN_ID_1), amount); // Total supply should remain unchanged
    }

    function test_safeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;
        transferAmounts[0] = 300;
        transferAmounts[1] = 500;

        // Set TTL for all tokens first
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        vm.stopPrank();

        // Mint tokens to alice
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Alice transfers to bob
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, transferAmounts);

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - transferAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - transferAmounts[1]);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmounts[0]);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), transferAmounts[1]);
    }

    function test_setApprovalForAll_and_transferFrom() public {
        uint256 amount = 1000;
        uint256 transferAmount = 400;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint tokens to alice
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob for all tokens
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));

        // Bob transfers from alice
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(bob, alice, charlie, TOKEN_ID_1, transferAmount);

        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, TOKEN_ID_1, transferAmount, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), transferAmount);
    }

    function test_multipleRoles() public {
        // Give alice multiple roles
        vm.startPrank(defaultAdmin);
        token.grantRole(MINTER_ROLE, alice);
        token.grantRole(BURNER_ROLE, alice);
        vm.stopPrank();

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Alice can mint
        vm.prank(alice);
        bool success = token.mint(bob, TOKEN_ID_1, 1000);
        assertTrue(success);

        // Alice can burn
        vm.prank(alice);
        success = token.burn(bob, TOKEN_ID_1, 500);
        assertTrue(success);

        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500);
    }

    function test_revokeRole() public {
        // Revoke minter role
        vm.expectEmit(true, true, true, false);
        emit RoleRevoked(MINTER_ROLE, minter, defaultAdmin);

        vm.prank(defaultAdmin);
        token.revokeRole(MINTER_ROLE, minter);

        assertFalse(token.hasRole(MINTER_ROLE, minter));

        // Should not be able to mint anymore
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, MINTER_ROLE)
        );
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
    }

    function test_defaultAdminTransfer() public {
        address newAdmin = makeAddr("newAdmin");

        // Schedule transfer
        vm.expectEmit(true, false, false, true);
        emit DefaultAdminTransferScheduled(newAdmin, uint48(block.timestamp + INITIAL_DELAY));

        vm.prank(defaultAdmin);
        token.beginDefaultAdminTransfer(newAdmin);

        // Fast forward time
        vm.warp(block.timestamp + INITIAL_DELAY + 1);

        // Accept transfer
        vm.prank(newAdmin);
        token.acceptDefaultAdminTransfer();

        assertEq(token.defaultAdmin(), newAdmin);
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, newAdmin));
        assertFalse(token.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
    }

    function test_cancelDefaultAdminTransfer() public {
        address newAdmin = makeAddr("newAdmin");

        // Schedule transfer
        vm.prank(defaultAdmin);
        token.beginDefaultAdminTransfer(newAdmin);

        // Cancel transfer
        vm.expectEmit(false, false, false, true);
        emit DefaultAdminTransferCanceled();

        vm.prank(defaultAdmin);
        token.cancelDefaultAdminTransfer();

        // Fast forward time
        vm.warp(block.timestamp + INITIAL_DELAY + 1);

        // Should not be able to accept
        vm.expectRevert();
        vm.prank(newAdmin);
        token.acceptDefaultAdminTransfer();

        assertEq(token.defaultAdmin(), defaultAdmin);
    }

    function test_renounceRole() public {
        // Token minter renounces their role
        vm.prank(minter);
        token.renounceRole(MINTER_ROLE, minter);

        assertFalse(token.hasRole(MINTER_ROLE, minter));

        // Should not be able to mint anymore
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, MINTER_ROLE)
        );
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
    }

    function test_setTokenPrice() public {
        uint256 price = 1 ether;

        vm.expectEmit(true, true, false, true);
        emit ERC1155PriceUpdated(tokenManager, TOKEN_ID_1, price);

        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, price);

        assertEq(token.priceOf(TOKEN_ID_1), price);
        assertTrue(token.priceIsSet(TOKEN_ID_1));
    }

    function test_setTokenPrice_unauthorized() public {
        uint256 price = 1 ether;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setPrice(TOKEN_ID_1, price);
    }

    function test_setTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectEmit(true, true, false, true);
        emit TreasuryUpdated(treasurer, newTreasury);

        vm.prank(treasurer);
        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
    }

    function test_setTreasury_unauthorized() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TREASURER_ROLE)
        );
        vm.prank(alice);
        token.setTreasury(newTreasury);
    }

    function test_setTTL() public {
        uint256 ttl = 30 days;

        vm.expectEmit(true, true, false, true);
        emit ERC1155TTLUpdated(tokenManager, TOKEN_ID_1, ttl);

        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, ttl);

        assertEq(token.ttlOf(TOKEN_ID_1), ttl);
    }

    function test_setTTL_unauthorized() public {
        uint256 ttl = 30 days;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTTL(TOKEN_ID_1, ttl);
    }

    function test_setNonTransferable() public {
        // Set token as non-transferable
        vm.expectEmit(true, false, false, true);
        emit ERC1155NonTransferableUpdated(TOKEN_ID_1, true);

        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        assertFalse(token.isTransferable(TOKEN_ID_1));

        // Set back to transferable
        vm.expectEmit(true, false, false, true);
        emit ERC1155NonTransferableUpdated(TOKEN_ID_1, false);

        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, false);

        assertTrue(token.isTransferable(TOKEN_ID_1));
    }

    function test_setNonTransferable_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setNonTransferable(TOKEN_ID_1, true);
    }

    function test_transfer_nonTransferableToken() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Set token as non-transferable
        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transfer - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");
    }

    function test_batchTransfer_nonTransferableToken() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;

        // Set TTL and mint tokens
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        vm.stopPrank();

        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Set one token as non-transferable
        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to batch transfer - should fail due to non-transferable token
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 100;
        transferAmounts[1] = 200;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");
    }

    function test_mint_nonTransferableToken() public {
        uint256 amount = 1000;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Set token as non-transferable
        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        // Minting should still work (minting is from address(0))
        vm.prank(minter);
        bool success = token.mint(alice, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_burn_nonTransferableToken() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Set token as non-transferable
        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        // Burning should still work (burning is to address(0))
        vm.prank(burner);
        bool success = token.burn(alice, TOKEN_ID_1, 500);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
    }

    function test_isFrozen_defaultState() public {
        // Accounts should not be frozen by default
        assertFalse(token.isFrozen(alice));
        assertFalse(token.isFrozen(bob));
        assertFalse(token.isFrozen(charlie));
    }

    function test_freezeAccount() public {
        bytes32 ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");

        // Freeze alice
        vm.expectEmit(true, true, false, true);
        emit AccountStatusUpdate(alice, ACCOUNT_FROZEN_STATUS);

        vm.prank(accessManager);
        token.freezeAccount(alice);

        assertTrue(token.isFrozen(alice));

        // Check frozen accounts list
        address[] memory frozen = token.frozenAccounts();
        assertEq(frozen.length, 1);
        assertEq(frozen[0], alice);
    }

    function test_freezeAccount_multiple() public {
        // Freeze multiple accounts
        vm.startPrank(accessManager);
        token.freezeAccount(alice);
        token.freezeAccount(bob);
        token.freezeAccount(charlie);
        vm.stopPrank();

        assertTrue(token.isFrozen(alice));
        assertTrue(token.isFrozen(bob));
        assertTrue(token.isFrozen(charlie));

        // Check frozen accounts list
        address[] memory frozen = token.frozenAccounts();
        assertEq(frozen.length, 3);
        assertEq(frozen[0], alice);
        assertEq(frozen[1], bob);
        assertEq(frozen[2], charlie);
    }

    function test_freezeAccount_duplicate() public {
        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to freeze alice again - should not emit event or add to list again
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Check frozen accounts list - should only have one entry
        address[] memory frozen = token.frozenAccounts();
        assertEq(frozen.length, 1);
        assertEq(frozen[0], alice);
    }

    function test_freezeAccount_zeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlInvalidAddress.selector, address(0))
        );
        vm.prank(accessManager);
        token.freezeAccount(address(0));
    }

    function test_freezeAccount_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.freezeAccount(bob);
    }

    function test_unfreezeAccount() public {
        bytes32 ACCOUNT_UNFROZEN_STATUS = keccak256("ACCOUNT_UNFROZEN_STATUS");

        // First freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);
        assertTrue(token.isFrozen(alice));

        // Unfreeze alice
        vm.expectEmit(true, true, false, true);
        emit AccountStatusUpdate(alice, ACCOUNT_UNFROZEN_STATUS);

        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        assertFalse(token.isFrozen(alice));

        // Check frozen accounts list - should be empty
        address[] memory frozen = token.frozenAccounts();
        assertEq(frozen.length, 0);
    }

    function test_unfreezeAccount_fromMultiple() public {
        // Freeze multiple accounts
        vm.startPrank(accessManager);
        token.freezeAccount(alice);
        token.freezeAccount(bob);
        token.freezeAccount(charlie);
        vm.stopPrank();

        // Unfreeze bob (middle of list)
        vm.prank(accessManager);
        token.unfreezeAccount(bob);

        assertFalse(token.isFrozen(bob));
        assertTrue(token.isFrozen(alice));
        assertTrue(token.isFrozen(charlie));

        // Check frozen accounts list
        address[] memory frozen = token.frozenAccounts();
        assertEq(frozen.length, 2);
        // Charlie should have replaced bob's position
        assertEq(frozen[0], alice);
        assertEq(frozen[1], charlie);
    }

    function test_unfreezeAccount_notFrozen() public {
        // Try to unfreeze an account that isn't frozen - should not revert or emit
        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        assertFalse(token.isFrozen(alice));
    }

    function test_unfreezeAccount_zeroAddress() public {
        vm.prank(accessManager);
        token.unfreezeAccount(address(0));

        // Should not revert, but also should not change anything
        assertFalse(token.isFrozen(address(0)));
    }

    function test_unfreezeAccount_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.unfreezeAccount(bob);
    }

    function test_transfer_frozenSender() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to transfer - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");
    }

    function test_transfer_frozenReceiver() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Freeze bob
        vm.prank(accessManager);
        token.freezeAccount(bob);

        // Try to transfer to frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, bob));
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");
    }

    function test_batchTransfer_frozenSender() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to batch transfer - should fail
        uint256[] memory transferAmounts = new uint256[](1);
        transferAmounts[0] = 100;

        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");
    }

    function test_mint_frozenReceiver() public {
        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to mint to frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
    }

    function test_mintBatch_frozenReceiver() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to mint batch to frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);
    }

    function test_burn_frozenAccount() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to burn from frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 500);
    }

    function test_burnBatch_frozenAccount() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to burn batch from frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155AccessControl.ERC1155AccessControlAccountFrozen.selector, alice));
        vm.prank(burner);
        token.burnBatch(alice, ids, amounts);
    }

    function test_suspendPrice() public {
        // Set initial price
        uint256 price = 1 ether;
        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, price);

        // Suspend the price
        vm.expectEmit(true, false, false, true);
        emit ERC1155PriceSuspended(tokenManager, TOKEN_ID_1);

        vm.prank(tokenManager);
        token.suspendPrice(TOKEN_ID_1);

        assertFalse(token.priceIsSet(TOKEN_ID_1));
    }

    function test_suspendPrice_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.suspendPrice(TOKEN_ID_1);
    }

    function test_pause() public {
        vm.expectEmit(true, false, false, true);
        emit Paused(accessManager);

        vm.prank(accessManager);
        token.pause();

        assertTrue(token.paused());
    }

    function test_pause_alreadyPaused() public {
        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to pause again - should revert
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(accessManager);
        token.pause();
    }

    function test_pause_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.pause();
    }

    function test_unpause() public {
        // First pause the contract
        vm.prank(accessManager);
        token.pause();
        assertTrue(token.paused());

        // Unpause
        vm.expectEmit(true, false, false, true);
        emit Unpaused(accessManager);

        vm.prank(accessManager);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_unpause_notPaused() public {
        // Try to unpause when not paused - should revert
        vm.expectRevert(Pausable.ExpectedPause.selector);
        vm.prank(accessManager);
        token.unpause();
    }

    function test_unpause_unauthorized() public {
        // First pause the contract
        vm.prank(accessManager);
        token.pause();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.unpause();
    }

    function test_transfer_whenPaused() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to transfer - should fail
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");
    }

    function test_batchTransfer_whenPaused() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to batch transfer - should fail
        uint256[] memory transferAmounts = new uint256[](1);
        transferAmounts[0] = 100;

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");
    }

    function test_mint_whenPaused() public {
        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to mint - should fail
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
    }

    function test_mintBatch_whenPaused() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to mint batch - should fail
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);
    }

    function test_burn_whenPaused() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to burn - should fail
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 500);
    }

    function test_burnBatch_whenPaused() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        amounts[0] = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Pause the contract
        vm.prank(accessManager);
        token.pause();

        // Try to burn batch - should fail
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(burner);
        token.burnBatch(alice, ids, amounts);
    }

    function test_balanceOfBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;
        amounts[0] = 1000;
        amounts[1] = 2000;
        amounts[2] = 3000;

        // Set TTL for all tokens first
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        token.setTTL(TOKEN_ID_3, 0); // Non-expiring
        vm.stopPrank();

        // Mint tokens to different accounts
        vm.startPrank(minter);
        token.mint(alice, TOKEN_ID_1, amounts[0]);
        token.mint(bob, TOKEN_ID_2, amounts[1]);
        token.mint(charlie, TOKEN_ID_3, amounts[2]);
        vm.stopPrank();

        // Prepare batch balance query
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = charlie;

        uint256[] memory balances = token.balanceOfBatch(accounts, ids);

        assertEq(balances[0], amounts[0]);
        assertEq(balances[1], amounts[1]);
        assertEq(balances[2], amounts[2]);
    }

    function test_totalSupply() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 2000;
        uint256 burnAmount = 500;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint to multiple users
        vm.startPrank(minter);
        token.mint(alice, TOKEN_ID_1, amount1);
        token.mint(bob, TOKEN_ID_1, amount2);
        vm.stopPrank();

        assertEq(token.totalSupply(TOKEN_ID_1), amount1 + amount2);

        // Burn some tokens
        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, burnAmount);

        assertEq(token.totalSupply(TOKEN_ID_1), amount1 + amount2 - burnAmount);

        // Test total supply across all tokens
        _setTokenTTL(TOKEN_ID_2, 60 days);
        vm.prank(minter);
        token.mint(charlie, TOKEN_ID_2, 500);

        assertEq(token.totalSupply(), amount1 + amount2 - burnAmount + 500);
    }

    function test_complexScenario() public {
        // Set TTL for all tokens
        vm.startPrank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTTL(TOKEN_ID_2, 60 days);
        token.setTTL(TOKEN_ID_3, 0); // Non-expiring
        vm.stopPrank();

        // Prepare batch data
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_3;
        amounts[0] = 1000;
        amounts[1] = 2000;
        amounts[2] = 3000;

        // Batch mint different tokens to alice
        vm.prank(minter);
        token.mintBatch(alice, ids, amounts);

        // Mint some individual tokens to bob
        vm.startPrank(minter);
        token.mint(bob, TOKEN_ID_1, 500);
        token.mint(bob, TOKEN_ID_2, 1000);
        vm.stopPrank();

        // Alice sets approval for all to charlie
        vm.prank(alice);
        token.setApprovalForAll(charlie, true);

        // Charlie transfers some tokens from alice to bob
        vm.prank(charlie);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 200, "");

        // Batch transfer from alice to bob via charlie
        uint256[] memory transferIds = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        transferIds[0] = TOKEN_ID_2;
        transferIds[1] = TOKEN_ID_3;
        transferAmounts[0] = 500;
        transferAmounts[1] = 1000;

        vm.prank(charlie);
        token.safeBatchTransferFrom(alice, bob, transferIds, transferAmounts, "");

        // Burn some tokens
        vm.startPrank(burner);
        token.burn(alice, TOKEN_ID_1, 300);
        token.burnBatch(bob, transferIds, transferAmounts);
        vm.stopPrank();

        // Verify final balances
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - 200 - 300); // 500
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - 500); // 1500
        assertEq(token.balanceOf(alice, TOKEN_ID_3), amounts[2] - 1000); // 2000

        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500 + 200); // 700
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 1000 + 500 - 500); // 1000 (burned the transferred amount)
        assertEq(token.balanceOf(bob, TOKEN_ID_3), 0 + 1000 - 1000); // 0 (burned the transferred amount)

        // Verify total supplies
        assertEq(token.totalSupply(TOKEN_ID_1), amounts[0] + 500 - 300); // 1200
        assertEq(token.totalSupply(TOKEN_ID_2), amounts[1] + 1000 - 500); // 2500
        assertEq(token.totalSupply(TOKEN_ID_3), amounts[2] - 1000); // 2000

        // Verify approval
        assertTrue(token.isApprovedForAll(alice, charlie));
    }

    function test_uri_withTokenSpecificURI() public {
        string memory baseURI = "https://example.com/metadata/";
        string memory tokenURI = "https://example.com/token/1.json";

        // Set base URI
        vm.prank(tokenManager);
        token.setURI(baseURI);

        // Set specific token URI
        vm.prank(tokenManager);
        token.setTokenURI(TOKEN_ID_1, tokenURI);

        // Token with specific URI should return that URI
        assertEq(token.uri(TOKEN_ID_1), tokenURI);

        // Token without specific URI should return base URI
        assertEq(token.uri(TOKEN_ID_2), baseURI);
    }

    function test_exists() public {
        // Token should not exist initially
        assertFalse(token.exists(TOKEN_ID_1));

        // Set TTL and mint
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);

        // Token should exist after minting
        assertTrue(token.exists(TOKEN_ID_1));

        // Burn all tokens
        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 1000);

        // Token should not exist after burning all
        assertFalse(token.exists(TOKEN_ID_1));
    }
}