// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909AccessControl} from "src/ERC6909/IERC6909AccessControl.sol";
import {IERC6909AccessControlPrice} from "src/ERC6909/IERC6909AccessControlPrice.sol";
import {ERC6909AccessControlPrice} from "src/ERC6909/ERC6909AccessControlPrice.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ERC6909AccessControlPriceTest is Test {
    ERC6909AccessControlPrice public token;

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
    event ERC6909PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC6909PriceSuspended(address caller, uint256 indexed id);

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
        token = new ERC6909AccessControlPrice(INITIAL_DELAY, defaultAdmin, treasury);

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
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909AccessControlPrice).interfaceId));
    }

    function test_roles() public view {
        assertTrue(token.hasRole(TREASURER_ROLE, treasurer));
        assertFalse(token.hasRole(TREASURER_ROLE, alice));
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

        assertFalse(token.isPriceSet(TOKEN_ID_1));
    }

    function test_suspendPrice_unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, TOKEN_MANAGER_ROLE)
        );
        vm.prank(alice);
        token.suspendPrice(TOKEN_ID_1);
    }

    function test_balanceOf() public {
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_update() public {
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 500);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);

        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 200);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 300);

        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 100);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 100);
    }
}
