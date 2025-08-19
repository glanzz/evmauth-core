// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909AccessControl} from "src/ERC6909/IERC6909AccessControl.sol";
import {ERC6909AccessControl} from "src/ERC6909/ERC6909AccessControl.sol";
import {ERC6909Base} from "src/ERC6909/extensions/ERC6909Base.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IERC6909ContentURI} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IERC6909Metadata} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IERC6909TokenSupply} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract ERC6909AccessControlTest is Test {
    ERC6909AccessControl public token;

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

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    // Events
    event ContractURIUpdated();
    event URI(string value, uint256 indexed id);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed spender, bool approved);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event DefaultAdminTransferScheduled(address indexed newAdmin, uint48 acceptSchedule);
    event DefaultAdminTransferCanceled();
    event DefaultAdminDelayChangeScheduled(uint48 newDelay, uint48 effectSchedule);
    event DefaultAdminDelayChangeCanceled();
    event Purchase(address caller, address indexed receiver, uint256 indexed id, uint256 amount, uint256 totalPrice);
    event ERC6909PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC6909PriceSuspended(address caller, uint256 indexed id);
    event ERC6909NonTransferableUpdated(uint256 indexed id, bool nonTransferable);
    event AccountStatusUpdate(address indexed account, bytes32 indexed status);
    event Paused(address account);
    event Unpaused(address account);

    // Helper function to set TTL for a token (required before minting with ERC6909TTL)
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
        token = new ERC6909AccessControl(INITIAL_DELAY, defaultAdmin, treasury);

        // Grant roles
        vm.startPrank(defaultAdmin);
        token.grantRole(TOKEN_MANAGER_ROLE, tokenManager);
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(BURNER_ROLE, burner);
        token.grantRole(TREASURER_ROLE, treasurer);
        token.grantRole(ACCESS_MANAGER_ROLE, accessManager); // Default admin is also an operator
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(token.defaultAdmin(), defaultAdmin);
        assertEq(token.defaultAdminDelay(), INITIAL_DELAY);
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertEq(token.treasury(), treasury);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
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

    function test_setContractURI() public {
        string memory uri = "https://example.com/contract-metadata";

        vm.expectEmit(false, false, false, true);
        emit ContractURIUpdated();

        vm.prank(tokenManager);
        token.setContractURI(uri);

        assertEq(token.contractURI(), uri);
    }

    function test_setContractURI_unauthorized() public {
        string memory uri = "https://example.com/contract-metadata";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setContractURI(uri);
    }

    function test_setTokenURI() public {
        string memory uri = "https://example.com/token/1";

        vm.expectEmit(true, true, false, true);
        emit URI(uri, TOKEN_ID_1);

        vm.prank(tokenManager);
        token.setTokenURI(TOKEN_ID_1, uri);

        assertEq(token.tokenURI(TOKEN_ID_1), uri);
    }

    function test_setTokenURI_unauthorized() public {
        string memory uri = "https://example.com/token/1";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTokenURI(TOKEN_ID_1, uri);
    }

    function test_setTokenName() public {
        string memory name = "Test Token";

        vm.prank(tokenManager);
        token.setTokenName(TOKEN_ID_1, name);

        assertEq(token.name(TOKEN_ID_1), name);
    }

    function test_setTokenName_unauthorized() public {
        string memory name = "Test Token";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTokenName(TOKEN_ID_1, name);
    }

    function test_setTokenSymbol() public {
        string memory symbol = "TEST";

        vm.prank(tokenManager);
        token.setTokenSymbol(TOKEN_ID_1, symbol);

        assertEq(token.symbol(TOKEN_ID_1), symbol);
    }

    function test_setTokenSymbol_unauthorized() public {
        string memory symbol = "TEST";

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTokenSymbol(TOKEN_ID_1, symbol);
    }

    function test_setTokenDecimals() public {
        uint8 decimals = 18;

        vm.prank(tokenManager);
        token.setTokenDecimals(TOKEN_ID_1, decimals);

        assertEq(token.decimals(TOKEN_ID_1), decimals);
    }

    function test_setTokenDecimals_unauthorized() public {
        uint8 decimals = 18;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.setTokenDecimals(TOKEN_ID_1, decimals);
    }

    function test_mint() public {
        uint256 amount = 1000;

        // Set TTL first (required by ERC6909TTL)
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);

        vm.expectEmit(true, true, true, true);
        emit Transfer(minter, address(0), alice, TOKEN_ID_1, amount);

        vm.prank(minter);
        bool success = token.mint(alice, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
        assertEq(token.totalSupply(TOKEN_ID_1), amount);
    }

    function test_mint_multipleTokenTypes() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 2000;
        uint256 amount3 = 3000;

        // Set TTL for all tokens first (required by ERC6909TTL)
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
        emit Transfer(burner, alice, address(0), TOKEN_ID_1, burnAmount);

        vm.prank(burner);
        bool success = token.burn(alice, TOKEN_ID_1, burnAmount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmount - burnAmount);
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmount - burnAmount);
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

    function test_transfer() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint tokens to alice
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice transfers to bob
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, alice, bob, TOKEN_ID_1, transferAmount);

        vm.prank(alice);
        bool success = token.transfer(bob, TOKEN_ID_1, transferAmount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
        assertEq(token.totalSupply(TOKEN_ID_1), amount); // Total supply should remain unchanged
    }

    function test_approve_and_transferFrom() public {
        uint256 amount = 1000;
        uint256 approveAmount = 600;
        uint256 transferAmount = 400;

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint tokens to alice
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, TOKEN_ID_1, approveAmount);

        vm.prank(alice);
        bool success = token.approve(bob, TOKEN_ID_1, approveAmount);
        assertTrue(success);

        assertEq(token.allowance(alice, bob, TOKEN_ID_1), approveAmount);

        // Bob transfers from alice
        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, charlie, TOKEN_ID_1, transferAmount);

        vm.prank(bob);
        success = token.transferFrom(alice, charlie, TOKEN_ID_1, transferAmount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), transferAmount);
        assertEq(token.allowance(alice, bob, TOKEN_ID_1), approveAmount - transferAmount);
    }

    function test_setOperator() public {
        // Alice sets bob as operator
        vm.expectEmit(true, true, false, true);
        emit OperatorSet(alice, bob, true);

        vm.prank(alice);
        bool success = token.setOperator(bob, true);
        assertTrue(success);

        assertTrue(token.isOperator(alice, bob));

        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Mint tokens to alice
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);

        // Bob can transfer alice's tokens as operator
        vm.prank(bob);
        success = token.transferFrom(alice, charlie, TOKEN_ID_1, 500);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), 500);
    }

    function test_metadata() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint8 decimals = 18;
        string memory uri = "https://example.com/token/1";

        vm.startPrank(tokenManager);
        token.setTokenName(TOKEN_ID_1, name);
        token.setTokenSymbol(TOKEN_ID_1, symbol);
        token.setTokenDecimals(TOKEN_ID_1, decimals);
        token.setTokenURI(TOKEN_ID_1, uri);
        vm.stopPrank();

        assertEq(token.name(TOKEN_ID_1), name);
        assertEq(token.symbol(TOKEN_ID_1), symbol);
        assertEq(token.decimals(TOKEN_ID_1), decimals);
        assertEq(token.tokenURI(TOKEN_ID_1), uri);
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
        emit ERC6909PriceUpdated(tokenManager, TOKEN_ID_1, price);

        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, price);

        assertEq(token.priceOf(TOKEN_ID_1), price);
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
        emit ERC6909NonTransferableUpdated(TOKEN_ID_1, true);

        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        assertFalse(token.isTransferable(TOKEN_ID_1));

        // Set back to transferable
        vm.expectEmit(true, false, false, true);
        emit ERC6909NonTransferableUpdated(TOKEN_ID_1, false);

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
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 100);
    }

    function test_transferFrom_nonTransferableToken() public {
        uint256 amount = 1000;

        // Set TTL and mint tokens
        _setTokenTTL(TOKEN_ID_1, 30 days);
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, TOKEN_ID_1, amount);

        // Set token as non-transferable
        vm.prank(tokenManager);
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transferFrom - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(bob);
        token.transferFrom(alice, charlie, TOKEN_ID_1, 100);
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
            abi.encodeWithSelector(ERC6909AccessControl.ERC6909AccessControlInvalidAddress.selector, address(0))
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
        bytes32 ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");
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
        vm.expectRevert(abi.encodeWithSelector(ERC6909AccessControl.ERC6909AccessControlAccountFrozen.selector, alice));
        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 100);
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
        vm.expectRevert(abi.encodeWithSelector(ERC6909AccessControl.ERC6909AccessControlAccountFrozen.selector, bob));
        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 100);
    }

    function test_mint_frozenReceiver() public {
        // Set TTL first
        _setTokenTTL(TOKEN_ID_1, 30 days);

        // Freeze alice
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to mint to frozen account - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC6909AccessControl.ERC6909AccessControlAccountFrozen.selector, alice));
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
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
        vm.expectRevert(abi.encodeWithSelector(ERC6909AccessControl.ERC6909AccessControlAccountFrozen.selector, alice));
        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 500);
    }

    function test_suspendPrice() public {
        // Set initial price
        uint256 price = 1 ether;
        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, price);

        // Suspend the price
        vm.expectEmit(true, false, false, true);
        emit ERC6909PriceSuspended(tokenManager, TOKEN_ID_1);

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
        token.transfer(bob, TOKEN_ID_1, 100);
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

    function test_complexScenario() public {
        // Set metadata and TTL
        vm.startPrank(tokenManager);
        token.setTokenName(TOKEN_ID_1, "Gold");
        token.setTokenSymbol(TOKEN_ID_1, "GLD");
        token.setTokenDecimals(TOKEN_ID_1, 18);
        token.setTTL(TOKEN_ID_1, 30 days);
        token.setTokenName(TOKEN_ID_2, "Silver");
        token.setTokenSymbol(TOKEN_ID_2, "SLV");
        token.setTokenDecimals(TOKEN_ID_2, 18);
        token.setTTL(TOKEN_ID_2, 60 days);
        vm.stopPrank();

        // Mint different tokens
        vm.startPrank(minter);
        token.mint(alice, TOKEN_ID_1, 10000);
        token.mint(alice, TOKEN_ID_2, 20000);
        token.mint(bob, TOKEN_ID_1, 5000);
        vm.stopPrank();

        // Alice transfers some tokens to charlie
        vm.startPrank(alice);
        token.transfer(charlie, TOKEN_ID_1, 2000);
        token.transfer(charlie, TOKEN_ID_2, 3000);
        vm.stopPrank();

        // Bob approves charlie to spend his tokens
        vm.prank(bob);
        token.approve(charlie, TOKEN_ID_1, 1000);

        // Charlie transfers from bob
        vm.prank(charlie);
        token.transferFrom(bob, alice, TOKEN_ID_1, 500);

        // Burn some tokens
        vm.startPrank(burner);
        token.burn(alice, TOKEN_ID_1, 1000);
        token.burn(charlie, TOKEN_ID_2, 1000);
        vm.stopPrank();

        // Verify final balances
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 10000 - 2000 + 500 - 1000); // 7500
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 20000 - 3000); // 17000
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 5000 - 500); // 4500
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), 2000); // 2000
        assertEq(token.balanceOf(charlie, TOKEN_ID_2), 3000 - 1000); // 2000

        // Verify total supplies
        assertEq(token.totalSupply(TOKEN_ID_1), 10000 + 5000 - 1000); // 14000
        assertEq(token.totalSupply(TOKEN_ID_2), 20000 - 1000); // 19000

        // Verify allowance
        assertEq(token.allowance(bob, charlie, TOKEN_ID_1), 1000 - 500); // 500
    }
}
