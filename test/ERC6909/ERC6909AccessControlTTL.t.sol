// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909AccessControl} from "src/ERC6909/IERC6909AccessControl.sol";
import {IERC6909AccessControlTTL} from "src/ERC6909/IERC6909AccessControlTTL.sol";
import {ERC6909AccessControlTTL} from "src/ERC6909/ERC6909AccessControlTTL.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ERC6909AccessControlTTLTest is Test {
    ERC6909AccessControlTTL public token;

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
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(treasurer, 100 ether);

        vm.prank(defaultAdmin);
        token = new ERC6909AccessControlTTL(INITIAL_DELAY, defaultAdmin);

        // Grant roles
        vm.startPrank(defaultAdmin);
        token.grantRole(TOKEN_MANAGER_ROLE, tokenManager);
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(BURNER_ROLE, burner);
        token.grantRole(ACCESS_MANAGER_ROLE, accessManager);
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(token.defaultAdmin(), defaultAdmin);
        assertEq(token.defaultAdminDelay(), INITIAL_DELAY);
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin));
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909AccessControl).interfaceId));
        assertTrue(token.supportsInterface(type(IERC6909AccessControlTTL).interfaceId));
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

    function test_balanceOf() public {
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);

        vm.prank(minter);
        token.mint(alice, TOKEN_ID_1, 1000);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);

        // Verify balance after token expiration
        vm.warp(block.timestamp + 31 days);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_update() public {
        vm.prank(tokenManager);
        token.setTTL(TOKEN_ID_1, 30 days);

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
