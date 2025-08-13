// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909Base} from "../../src/erc6909/IERC6909Base.sol";
import {ERC6909Base} from "../../src/erc6909/ERC6909Base.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";

contract MockERC6909Base is ERC6909Base {
    // This contract is for testing purposes only, so it performs no permission checks

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}

contract ERC6909BaseTest is Test {
    MockERC6909Base public token;

    address public alice;
    address public bob;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;

    // ERC6909 Events
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new MockERC6909Base();
    }

    function test_supportsInterface() public view {
        // Test that it supports the base ERC6909 interface
        assertTrue(token.supportsInterface(type(IERC6909).interfaceId));

        // Test ERC165 interface support
        assertTrue(token.supportsInterface(0x01ffc9a7)); // ERC165 interface ID

        // Test that it returns false for unsupported interfaces
        assertFalse(token.supportsInterface(0xffffffff));

        // Note: The individual extension interfaces (IERC6909ContentURI, IERC6909Metadata, IERC6909TokenSupply)
        // don't explicitly register their interface IDs in the OpenZeppelin implementation,
        // they only override supportsInterface to call the parent implementation
    }

    function test_updateThroughMint() public {
        uint256 amount = 1000;

        // Test that _update is called correctly through mint
        // This verifies that both ERC6909 and ERC6909TokenSupply's _update are called
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), address(0), alice, TOKEN_ID_1, amount);

        token.mint(alice, TOKEN_ID_1, amount);

        // Verify the balance was updated (tests ERC6909._update)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);

        // Verify the total supply was updated (tests ERC6909TokenSupply._update)
        assertEq(token.totalSupply(TOKEN_ID_1), amount);
    }

    function test_updateThroughBurn() public {
        uint256 mintAmount = 1000;
        uint256 burnAmount = 400;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, mintAmount);

        // Test that _update is called correctly through burn
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), alice, address(0), TOKEN_ID_1, burnAmount);

        token.burn(alice, TOKEN_ID_1, burnAmount);

        // Verify the balance was updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmount - burnAmount);

        // Verify the total supply was updated
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmount - burnAmount);
    }

    function test_updateThroughTransfer() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, amount);

        // Test that _update is called correctly through transfer
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, alice, bob, TOKEN_ID_1, transferAmount);

        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, transferAmount);

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);

        // Verify total supply remains the same (transfers don't change supply)
        assertEq(token.totalSupply(TOKEN_ID_1), amount);
    }

    function test_multipleTokenTypes() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 2000;

        // Mint different token types
        token.mint(alice, TOKEN_ID_1, amount1);
        token.mint(alice, TOKEN_ID_2, amount2);

        // Verify balances are tracked separately
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount1);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amount2);

        // Verify total supplies are tracked separately
        assertEq(token.totalSupply(TOKEN_ID_1), amount1);
        assertEq(token.totalSupply(TOKEN_ID_2), amount2);

        // Burn from one token type shouldn't affect the other
        token.burn(alice, TOKEN_ID_1, 500);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount1 - 500);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amount2); // Unchanged
        assertEq(token.totalSupply(TOKEN_ID_1), amount1 - 500);
        assertEq(token.totalSupply(TOKEN_ID_2), amount2); // Unchanged
    }
}
