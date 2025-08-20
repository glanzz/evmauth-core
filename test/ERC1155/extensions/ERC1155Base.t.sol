// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155Base} from "src/ERC1155/extensions/IERC1155Base.sol";
import {ERC1155Base} from "src/ERC1155/extensions/ERC1155Base.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MockERC1155Base is ERC1155Base {
    // This contract is for testing purposes only, so it performs no permission checks

    constructor() ERC1155Base("https://example.com/api/token/{id}.json") {}

    function mint(address to, uint256 id, uint256 amount) external returns (bool) {
        _mint(to, id, amount, "");
        return true;
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external returns (bool) {
        _mintBatch(to, ids, amounts, "");
        return true;
    }

    function burn(address from, uint256 id, uint256 amount) external returns (bool) {
        _burn(from, id, amount);
        return true;
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external returns (bool) {
        _burnBatch(from, ids, amounts);
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

    function setTokenURI(uint256 id, string memory tokenURI) external {
        _setURI(id, tokenURI);
    }

    function setBaseURI(string memory baseURI) external {
        _setBaseURI(baseURI);
    }
}

contract ERC1155BaseTest is Test {
    MockERC1155Base public token;

    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;

    // Events
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    event ERC1155NonTransferableUpdated(uint256 indexed id, bool nonTransferable);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new MockERC1155Base();
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Base).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155MetadataURI).interfaceId));

        // Test that it returns false for unsupported interfaces
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_isTransferable_defaultState() public view {
        // Tokens should be transferable by default
        assertTrue(token.isTransferable(TOKEN_ID_1));
        assertTrue(token.isTransferable(TOKEN_ID_2));
    }

    function test_setNonTransferable() public {
        // Set token as non-transferable
        vm.expectEmit(true, false, false, true);
        emit ERC1155NonTransferableUpdated(TOKEN_ID_1, true);

        token.setNonTransferable(TOKEN_ID_1, true);
        assertFalse(token.isTransferable(TOKEN_ID_1));

        // Set back to transferable
        vm.expectEmit(true, false, false, true);
        emit ERC1155NonTransferableUpdated(TOKEN_ID_1, false);

        token.setNonTransferable(TOKEN_ID_1, false);
        assertTrue(token.isTransferable(TOKEN_ID_1));
    }

    function test_mint() public {
        uint256 amount = 1000;

        // Test that _update is called correctly through mint
        // This verifies that both ERC1155 and ERC1155Supply's _update are called
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);

        token.mint(alice, TOKEN_ID_1, amount);

        // Verify the balance was updated (tests ERC1155._update)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);

        // Verify the total supply was updated (tests ERC1155Supply._update)
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

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), alice, ids, amounts);

        token.mintBatch(alice, ids, amounts);

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1]);

        // Verify total supplies were updated
        assertEq(token.totalSupply(TOKEN_ID_1), amounts[0]);
        assertEq(token.totalSupply(TOKEN_ID_2), amounts[1]);
        assertTrue(token.exists(TOKEN_ID_1));
        assertTrue(token.exists(TOKEN_ID_2));
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

    function test_mintBatch_paused() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt mint batch while paused - should revert
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.mintBatch(alice, ids, amounts);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Mint batch should now succeed
        token.mintBatch(alice, ids, amounts);

        // Verify the balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1]);
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

    function test_burn() public {
        uint256 mintAmount = 1000;
        uint256 burnAmount = 400;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, mintAmount);

        // Test that _update is called correctly through burn
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, burnAmount);

        token.burn(alice, TOKEN_ID_1, burnAmount);

        // Verify the balance was updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmount - burnAmount);

        // Verify the total supply was updated
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

        // Setup: mint some tokens first
        token.mintBatch(alice, ids, mintAmounts);

        // Test that _update is called correctly through burn batch
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, burnAmounts);

        token.burnBatch(alice, ids, burnAmounts);

        // Verify the balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmounts[0] - burnAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), mintAmounts[1] - burnAmounts[1]);

        // Verify the total supplies were updated
        assertEq(token.totalSupply(TOKEN_ID_1), mintAmounts[0] - burnAmounts[0]);
        assertEq(token.totalSupply(TOKEN_ID_2), mintAmounts[1] - burnAmounts[1]);
    }

    function test_burn_entireBalance() public {
        uint256 amount = 1000;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, amount);

        // Burn all tokens
        token.burn(alice, TOKEN_ID_1, amount);

        // Verify the balance was updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);

        // Verify the total supply was updated
        assertEq(token.totalSupply(TOKEN_ID_1), 0);

        // Token should no longer exist
        assertFalse(token.exists(TOKEN_ID_1));
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

    function test_burnBatch_paused() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory mintAmounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        mintAmounts[0] = 1000;
        mintAmounts[1] = 2000;
        burnAmounts[0] = 400;
        burnAmounts[1] = 800;

        // Setup: mint some tokens first
        token.mintBatch(alice, ids, mintAmounts);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt burn batch while paused - should revert
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.burnBatch(alice, ids, burnAmounts);

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Burn batch should now succeed
        token.burnBatch(alice, ids, burnAmounts);

        // Verify the balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), mintAmounts[0] - burnAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), mintAmounts[1] - burnAmounts[1]);
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

    function test_safeTransferFrom() public {
        uint256 amount = 1000;
        uint256 transferAmount = 300;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, amount);

        // Test that _update is called correctly through transfer
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, transferAmount);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, transferAmount, "");

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);

        // Verify total supply remains the same (transfers don't change supply)
        assertEq(token.totalSupply(TOKEN_ID_1), amount);
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

        // Setup: mint some tokens first
        token.mintBatch(alice, ids, amounts);

        // Test that _update is called correctly through batch transfer
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, transferAmounts);

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - transferAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - transferAmounts[1]);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmounts[0]);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), transferAmounts[1]);

        // Verify total supplies remain the same (transfers don't change supply)
        assertEq(token.totalSupply(TOKEN_ID_1), amounts[0]);
        assertEq(token.totalSupply(TOKEN_ID_2), amounts[1]);
    }

    function test_safeTransferFrom_paused() public {
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
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, transferAmount, "");

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Transfer should now succeed
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, transferAmount, "");

        // Verify the transfer worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmount);
    }

    function test_safeTransferFrom_nonTransferableToken() public {
        uint256 amount = 1000;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transfer - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");
    }

    function test_safeBatchTransferFrom_paused() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;
        transferAmounts[0] = 300;
        transferAmounts[1] = 500;

        // Setup: mint some tokens
        token.mintBatch(alice, ids, amounts);

        // Pause the contract
        token.pause();
        assertTrue(token.paused());

        // Attempt batch transfer while paused - should revert
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // Unpause the contract
        token.unpause();
        assertFalse(token.paused());

        // Batch transfer should now succeed
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // Verify the transfers worked
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - transferAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - transferAmounts[1]);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), transferAmounts[0]);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), transferAmounts[1]);
    }

    function test_safeBatchTransferFrom_nonTransferableToken() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;
        transferAmounts[0] = 100;
        transferAmounts[1] = 200;

        // Mint tokens
        token.mintBatch(alice, ids, amounts);

        // Set one token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to batch transfer - should fail due to non-transferable token
        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");
    }

    function test_safeTransferFrom_withOperator_nonTransferableToken() public {
        uint256 amount = 1000;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob as operator
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        // Set token as non-transferable
        token.setNonTransferable(TOKEN_ID_1, true);

        // Try to transfer as operator - should fail
        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_1));
        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, TOKEN_ID_1, 100, "");
    }

    function test_safeTransferFrom_toSelf() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155InvalidSelfTransfer.selector, alice));
        vm.prank(bob);
        token.safeTransferFrom(alice, alice, TOKEN_ID_1, 100, "");
    }

    function test_safeTransferFrom_zeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155InvalidZeroValueTransfer.selector));
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 0, "");
    }

    function test_setApprovalForAll_safeTransferFrom() public {
        uint256 amount = 1000;
        uint256 transferAmount = 400;

        // Setup: mint some tokens first
        token.mint(alice, TOKEN_ID_1, amount);

        // Alice approves bob for all tokens
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));

        // Bob transfers from alice to charlie
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(bob, alice, charlie, TOKEN_ID_1, transferAmount);

        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, TOKEN_ID_1, transferAmount, "");

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount - transferAmount);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), transferAmount);
    }

    function test_setApprovalForAll_safeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;
        transferAmounts[0] = 300;
        transferAmounts[1] = 500;

        // Setup: mint some tokens first
        token.mintBatch(alice, ids, amounts);

        // Alice approves bob for all tokens
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));

        // Bob batch transfers from alice to charlie
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(bob, alice, charlie, ids, transferAmounts);

        vm.prank(bob);
        token.safeBatchTransferFrom(alice, charlie, ids, transferAmounts, "");

        // Verify balances were updated
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - transferAmounts[0]);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - transferAmounts[1]);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), transferAmounts[0]);
        assertEq(token.balanceOf(charlie, TOKEN_ID_2), transferAmounts[1]);
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

    function test_totalSupply() public {
        uint256 amount1 = 1000;
        uint256 amount2 = 2000;
        uint256 amount3 = 3000;

        // Test single token total supply
        token.mint(alice, TOKEN_ID_1, amount1);
        assertEq(token.totalSupply(TOKEN_ID_1), amount1);
        assertEq(token.totalSupply(), amount1);

        // Test multiple tokens total supply
        token.mint(bob, TOKEN_ID_2, amount2);
        assertEq(token.totalSupply(TOKEN_ID_1), amount1);
        assertEq(token.totalSupply(TOKEN_ID_2), amount2);
        assertEq(token.totalSupply(), amount1 + amount2);

        // Test burning affects total supply
        token.burn(alice, TOKEN_ID_1, 500);
        assertEq(token.totalSupply(TOKEN_ID_1), amount1 - 500);
        assertEq(token.totalSupply(), amount1 - 500 + amount2);

        // Test additional minting to same token ID
        token.mint(charlie, TOKEN_ID_1, amount3);
        assertEq(token.totalSupply(TOKEN_ID_1), amount1 - 500 + amount3);
        assertEq(token.totalSupply(), amount1 - 500 + amount3 + amount2);
    }

    function test_exists() public {
        // Token should not exist initially
        assertFalse(token.exists(TOKEN_ID_1));

        // Token should exist after minting
        token.mint(alice, TOKEN_ID_1, 1000);
        assertTrue(token.exists(TOKEN_ID_1));

        // Token should still exist after partial burn
        token.burn(alice, TOKEN_ID_1, 500);
        assertTrue(token.exists(TOKEN_ID_1));

        // Token should not exist after burning all
        token.burn(alice, TOKEN_ID_1, 500);
        assertFalse(token.exists(TOKEN_ID_1));
    }

    function test_balanceOfBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_1; // Same ID for different user
        amounts[0] = 1000;
        amounts[1] = 2000;
        amounts[2] = 3000;

        // Mint tokens to different accounts
        token.mint(alice, TOKEN_ID_1, amounts[0]);
        token.mint(bob, TOKEN_ID_2, amounts[1]);
        token.mint(charlie, TOKEN_ID_1, amounts[2]);

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

    function test_uri_default() public view {
        // Test default URI
        string memory baseURI = "https://example.com/api/token/{id}.json";
        assertEq(token.uri(TOKEN_ID_1), baseURI);
        assertEq(token.uri(TOKEN_ID_2), baseURI);
    }

    function test_uri_withTokenSpecificURI() public {
        string memory baseURI = "https://example.com/metadata/";
        string memory tokenURI = "token/1.json";
        string memory fullURI = string.concat(baseURI, tokenURI);

        // Set base URI
        token.setBaseURI(baseURI);

        // Set specific token URI
        vm.expectEmit(true, false, false, true);
        emit URI(fullURI, TOKEN_ID_1);

        token.setTokenURI(TOKEN_ID_1, tokenURI);

        // Token with specific URI should return concatenated URI
        assertEq(token.uri(TOKEN_ID_1), fullURI);

        // Token without specific URI should return the original constructor URI (not the base URI)
        // because ERC1155URIStorage falls back to super.uri() which is ERC1155.uri()
        string memory constructorURI = "https://example.com/api/token/{id}.json";
        assertEq(token.uri(TOKEN_ID_2), constructorURI);
    }

    function test_complexScenario() public {
        // Test complex scenario with multiple operations
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        amounts[0] = 1000;
        amounts[1] = 2000;

        // Batch mint to alice
        token.mintBatch(alice, ids, amounts);

        // Mint individual tokens to bob
        token.mint(bob, TOKEN_ID_1, 500);
        token.mint(bob, TOKEN_ID_2, 1500);

        // Alice sets approval for all to charlie
        vm.prank(alice);
        token.setApprovalForAll(charlie, true);

        // Charlie transfers some tokens from alice to bob
        vm.prank(charlie);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 200, "");

        // Batch transfer from alice to charlie via operator
        uint256[] memory transferIds = new uint256[](2);
        uint256[] memory transferAmounts = new uint256[](2);
        transferIds[0] = TOKEN_ID_1;
        transferIds[1] = TOKEN_ID_2;
        transferAmounts[0] = 300;
        transferAmounts[1] = 500;

        vm.prank(charlie);
        token.safeBatchTransferFrom(alice, charlie, transferIds, transferAmounts, "");

        // Burn some tokens
        token.burn(alice, TOKEN_ID_1, 100);
        token.burnBatch(bob, transferIds, transferAmounts);

        // Verify final balances
        assertEq(token.balanceOf(alice, TOKEN_ID_1), amounts[0] - 200 - 300 - 100); // 400
        assertEq(token.balanceOf(alice, TOKEN_ID_2), amounts[1] - 500); // 1500
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500 + 200 - 300); // 400
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 1500 - 500); // 1000
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), 300);
        assertEq(token.balanceOf(charlie, TOKEN_ID_2), 500);

        // Verify total supplies
        // Total for TOKEN_ID_1: initial 1000 + 500 (minted to bob) - 100 (burned from alice) = 1400
        // But we also burned 300 from bob, so: 1400 - 300 = 1100
        assertEq(token.totalSupply(TOKEN_ID_1), amounts[0] + 500 - 100 - 300); // 1100
        // Total for TOKEN_ID_2: initial 2000 + 1500 (minted to bob) - 500 (burned from bob) = 3000
        assertEq(token.totalSupply(TOKEN_ID_2), amounts[1] + 1500 - 500); // 3000

        // Verify approval
        assertTrue(token.isApprovedForAll(alice, charlie));
    }

    function test_pause_and_unpause() public {
        // Test pause functionality
        token.pause();
        assertTrue(token.paused());

        // Test unpause functionality
        token.unpause();
        assertFalse(token.paused());
    }

    function test_nonTransferableToken_mixedBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = 3; // Third token ID
        amounts[0] = 1000;
        amounts[1] = 2000;
        amounts[2] = 3000;

        // Mint tokens
        token.mintBatch(alice, ids, amounts);

        // Set middle token as non-transferable
        token.setNonTransferable(TOKEN_ID_2, true);

        // Try to batch transfer - should fail due to non-transferable token
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 100;
        transferAmounts[1] = 200;
        transferAmounts[2] = 300;

        vm.expectRevert(abi.encodeWithSelector(ERC1155Base.ERC1155NonTransferableToken.selector, TOKEN_ID_2));
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // But individual transfers of transferable tokens should work
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 3, 300, "");

        assertEq(token.balanceOf(bob, TOKEN_ID_1), 100);
        assertEq(token.balanceOf(bob, 3), 300);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 0); // Couldn't transfer non-transferable token
    }
}
