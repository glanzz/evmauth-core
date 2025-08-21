// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {IERC1155Base} from "src/ERC1155/extensions/IERC1155Base.sol";
import {IERC1155TTL} from "src/ERC1155/extensions/IERC1155TTL.sol";
import {IERC1155AccessControl} from "src/ERC1155/IERC1155AccessControl.sol";
import {IERC1155AccessControlTTL} from "src/ERC1155/IERC1155AccessControlTTL.sol";
import {ERC1155AccessControlTTL} from "src/ERC1155/ERC1155AccessControlTTL.sol";

contract ERC1155AccessControlTTLTest is Test {
    ERC1155AccessControlTTL public token;

    address public owner;
    address public defaultAdmin;
    address public accessManager;
    address public tokenManager;
    address public minter;
    address public burner;
    address public alice;
    address public bob;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TTL_30_DAYS = 30 days;
    uint256 public constant TTL_1_YEAR = 365 days;

    event ERC1155TTLUpdated(address caller, uint256 indexed id, uint256 ttl);

    function setUp() public {
        owner = makeAddr("owner");
        defaultAdmin = makeAddr("defaultAdmin");
        accessManager = makeAddr("accessManager");
        tokenManager = makeAddr("tokenManager");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(owner);
        // Deploy with 2 hour delay for admin changes
        token = new ERC1155AccessControlTTL(2 hours, defaultAdmin, "https://example.com/api/token/");

        // Grant roles
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(token.defaultAdmin(), defaultAdmin);
        assertEq(token.defaultAdminDelay(), 2 hours);
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Base).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155TTL).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155AccessControlTTL).interfaceId));
    }

    function test_setTTL() public {
        vm.expectEmit(true, true, true, true);
        emit ERC1155TTLUpdated(tokenManager, TOKEN_ID_1, TTL_30_DAYS);

        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);

        assertEq(token.ttlOf(TOKEN_ID_1), TTL_30_DAYS);
        assertTrue(token.isTTLSet(TOKEN_ID_1));
    }

    function test_setTTL_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);
    }

    function test_balanceOf() public {
        // First set TTL for the token (required for TTL tokens)
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);

        // Then mint
        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_update() public {
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);

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

        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);

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

        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_2, TTL_1_YEAR);

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

        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, TTL_30_DAYS);

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
