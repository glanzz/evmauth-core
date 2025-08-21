// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {IERC1155Base} from "src/ERC1155/extensions/IERC1155Base.sol";
import {IERC1155Price} from "src/ERC1155/extensions/IERC1155Price.sol";
import {IERC1155AccessControl} from "src/ERC1155/IERC1155AccessControl.sol";
import {IERC1155AccessControlPrice} from "src/ERC1155/IERC1155AccessControlPrice.sol";
import {ERC1155AccessControlPrice} from "src/ERC1155/ERC1155AccessControlPrice.sol";

// Mock concrete implementation for testing
contract MockERC1155AccessControlPrice is ERC1155AccessControlPrice {
    constructor(uint48 initialDelay, address initialDefaultAdmin, address payable treasuryAccount, string memory uri_)
        ERC1155AccessControlPrice(initialDelay, initialDefaultAdmin, treasuryAccount, uri_)
    {}
}

contract ERC1155AccessControlPriceTest is Test {
    ERC1155AccessControlPrice public token;

    address public owner;
    address public defaultAdmin;
    address public accessManager;
    address public tokenManager;
    address public minter;
    address public burner;
    address public treasurer;
    address payable public treasury;
    address public alice;
    address public bob;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant PRICE_1 = 0.1 ether;
    uint256 public constant PRICE_2 = 0.2 ether;

    event ERC1155PriceUpdated(address caller, uint256 indexed id, uint256 price);
    event ERC1155PriceSuspended(address caller, uint256 indexed id);
    event TreasuryUpdated(address caller, address indexed account);

    function setUp() public {
        owner = makeAddr("owner");
        defaultAdmin = makeAddr("defaultAdmin");
        accessManager = makeAddr("accessManager");
        tokenManager = makeAddr("tokenManager");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        treasurer = makeAddr("treasurer");
        treasury = payable(makeAddr("treasury"));
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(owner);
        // Deploy with 2 hour delay for admin changes
        token = new MockERC1155AccessControlPrice(2 hours, defaultAdmin, treasury, "https://example.com/api/token/");

        // Grant roles
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }

    function test_constructor() public view {
        assertEq(token.treasury(), treasury);
        assertEq(token.defaultAdmin(), defaultAdmin);
        assertEq(token.defaultAdminDelay(), 2 hours);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Base).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Price).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155AccessControlPrice).interfaceId));
    }

    function test_setTokenPrice() public {
        vm.expectEmit(true, true, true, true);
        emit ERC1155PriceUpdated(tokenManager, TOKEN_ID_1, PRICE_1);

        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, PRICE_1);

        assertEq(token.priceOf(TOKEN_ID_1), PRICE_1);
        assertTrue(token.isPriceSet(TOKEN_ID_1));
    }

    function test_setTokenPrice_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setPrice(TOKEN_ID_1, PRICE_1);
    }

    function test_setTreasury() public {
        address payable newTreasury = payable(makeAddr("newTreasury"));

        vm.expectEmit(true, true, true, true);
        emit TreasuryUpdated(treasurer, newTreasury);

        vm.prank(treasurer);
        token.setTreasury(newTreasury);

        assertEq(token.treasury(), newTreasury);
    }

    function test_setTreasury_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTreasury(payable(alice));
    }

    function test_suspendPrice() public {
        // First set a price
        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, PRICE_1);
        assertTrue(token.isPriceSet(TOKEN_ID_1));

        // Then suspend it
        vm.expectEmit(true, true, true, true);
        emit ERC1155PriceSuspended(tokenManager, TOKEN_ID_1);

        vm.prank(tokenManager);
        token.suspendPrice(TOKEN_ID_1);

        assertFalse(token.isPriceSet(TOKEN_ID_1));
    }

    function test_suspendPrice_unauthorized() public {
        vm.prank(tokenManager);
        token.setPrice(TOKEN_ID_1, PRICE_1);

        vm.prank(alice);
        vm.expectRevert();
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
        token.mint(alice, TOKEN_ID_1, 1000);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 300, "");
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 700);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 300);

        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 200);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
    }

    function test_isTransferable() public view {
        // All tokens should be transferable by default
        assertTrue(token.isTransferable(TOKEN_ID_1));
        assertTrue(token.isTransferable(TOKEN_ID_2));
        assertTrue(token.isTransferable(999));
    }

    function test_totalSupply_single() public {
        assertEq(token.totalSupply(TOKEN_ID_1), 0);

        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
        assertEq(token.totalSupply(TOKEN_ID_1), 1000);

        vm.prank(minter);
        token.mint(bob, TOKEN_ID_1, 500);
        assertEq(token.totalSupply(TOKEN_ID_1), 1500);

        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 300);
        assertEq(token.totalSupply(TOKEN_ID_1), 1200);
    }

    function test_totalSupply_all() public {
        assertEq(token.totalSupply(), 0);

        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
        assertEq(token.totalSupply(), 1000);

        vm.prank(minter);
        token.mint(bob, TOKEN_ID_2, 2000);
        assertEq(token.totalSupply(), 3000);

        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 500);
        assertEq(token.totalSupply(), 2500);
    }

    function test_exists() public {
        assertFalse(token.exists(TOKEN_ID_1));

        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);
        assertTrue(token.exists(TOKEN_ID_1));

        vm.prank(burner);
        token.burn(alice, TOKEN_ID_1, 1000);
        assertFalse(token.exists(TOKEN_ID_1));
    }

    function test_uri() public view {
        string memory expectedUri = "https://example.com/api/token/";
        assertEq(token.uri(TOKEN_ID_1), expectedUri);
        assertEq(token.uri(TOKEN_ID_2), expectedUri);
        assertEq(token.uri(999), expectedUri);
    }
}
