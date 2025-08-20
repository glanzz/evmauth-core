// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC6909Base} from "src/ERC6909/extensions/IERC6909Base.sol";
import {ERC6909Base} from "src/ERC6909/extensions/ERC6909Base.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MockERC6909Base is ERC6909Base {
    // This contract is for testing purposes only, so it performs no permission checks

    function mint(address to, uint256 id, uint256 amount) external returns (bool) {
        _mint(to, id, amount);
        return true;
    }

    function burn(address from, uint256 id, uint256 amount) external returns (bool) {
        _burn(from, id, amount);
        return true;
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }

    function setNonTransferable(uint256 id, bool nonTransferable) external {
        _setNonTransferable(id, nonTransferable);
    }
}

contract ERC6909BaseTest is Test {
    MockERC6909Base public token;

    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;

    // Events
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);
    event ERC6909NonTransferableUpdated(uint256 indexed id, bool nonTransferable);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

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

    function test_isTransferable_defaultState() public {
        // Tokens should be transferable by default
        assertTrue(token.isTransferable(TOKEN_ID_1));
        assertTrue(token.isTransferable(TOKEN_ID_2));
    }

    function test_setNonTransferable() public {
        // Set token as non-transferable
        vm.expectEmit(true, false, false, true);
        emit ERC6909NonTransferableUpdated(TOKEN_ID_1, true);

        token.setNonTransferable(TOKEN_ID_1, true);
        assertFalse(token.isTransferable(TOKEN_ID_1));

        // Set back to transferable
        vm.expectEmit(true, false, false, true);
        emit ERC6909NonTransferableUpdated(TOKEN_ID_1, false);

        token.setNonTransferable(TOKEN_ID_1, false);
        assertTrue(token.isTransferable(TOKEN_ID_1));
    }

    function test_mint() public {
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

    function test_mint_paused() public {
        uint256 amount = 1000;

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt mint while paused - should revert
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.mint(alice, TOKEN_ID_1, amount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Mint should now succeed
        token.mint(alice, TOKEN_ID_1, amount);

        // Verify the balance was updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_mint_nonTransferableToken() public {
        uint256 amount = 1000;

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Minting should still work (minting is from address(0))
        bool success = token.mint(alice, TOKEN_ID_1, amount);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function mint_zeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidZeroValueTransfer.selector));
        token.mint(alice, TOKEN_ID_1, 0);
    }

    function test_burn() public {
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

    function test_burn_paused() public {
        uint256 mintAmount = 1000;
        uint256 burnAmount = 400;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, mintAmount);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt burn while paused - should revert
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.burn(alice, TOKEN_ID_1, burnAmount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Burn should now succeed
        token.burn(alice, TOKEN_ID_1, burnAmount);

        // Verify the balance was updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmount - burnAmount);

        // Verify the total supply was updated
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmount - burnAmount);
    }

    function test_burn_nonTransferableToken() public {
        uint256 amount = 1000;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Burning should still work (burning is to address(0))
        bool success = token.burn(alice, TOKEN_ID_1, 500);
        assertTrue(success);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
    }

    function burn_zeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidZeroValueTransfer.selector));
        token.burn(alice, TOKEN_ID_1, 0);
    }

    function test_transfer() public {
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

    function test_transfer_paused() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Setup: mint some tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt transfer while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(bob, TOKEN_ID_1, transferAmount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Transfer should now succeed
        vm.prank(alice);
        assertTrue(token.transfer(bob, TOKEN_ID_1, transferAmount));

        // Verify the transfer worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
    }

    function test_transfer_nonTransferableToken() public {
        uint256 amount = 1000;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transfer - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 100);
    }

    function transfer_toSelf() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidSelfTransfer.selector, alice));
        vm.prank(alice);
        token.transfer(alice, TOKEN_ID_1, 100);
    }

    function transfer_zeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidZeroValueTransfer.selector));
        vm.prank(alice);
        token.transfer(bob, TOKEN_ID_1, 0);
    }

    function test_transferFrom_paused() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Setup: mint some tokens and approve
        token.mint(alice, TOKEN_ID_1, amount);
        vm.prank(alice);
        token.approve(bob, TOKEN_ID_1, transferAmount);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt transferFrom while paused - should revert
        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transferFrom(alice, bob, TOKEN_ID_1, transferAmount);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // TransferFrom should now succeed
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, TOKEN_ID_1, transferAmount));

        // Verify the transfer worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
    }

    function test_transferFrom_withOperator_paused() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Setup: mint some tokens and set operator
        token.mint(alice, TOKEN_ID_1, amount);
        vm.prank(alice);
        token.setOperator(bob, true);

        // Pause the contract
        token.pause();

        // Attempt transferFrom as operator while paused - should revert
        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transferFrom(alice, bob, TOKEN_ID_1, transferAmount);

        // Unpause the contract
        token.unpause();

        // TransferFrom as operator should now succeed
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, TOKEN_ID_1, transferAmount));

        // Verify the transfer worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
    }

    function test_transferFrom_nonTransferableToken() public {
        uint256 amount = 1000;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, TOKEN_ID_1, amount);

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transferFrom - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(bob);
        token.transferFrom(alice, charlie, TOKEN_ID_1, 100);
    }

    function test_transferFrom_toSelf() public {
        vm.prank(alice);
        token.setOperator(bob, true);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidSelfTransfer.selector, alice));
        vm.prank(bob);
        token.transferFrom(alice, alice, TOKEN_ID_1, 100);
    }

    function test_transferFrom_zeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Base.ERC6909InvalidZeroValueTransfer.selector));
        vm.prank(bob);
        token.transferFrom(alice, charlie, TOKEN_ID_1, 0);
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
