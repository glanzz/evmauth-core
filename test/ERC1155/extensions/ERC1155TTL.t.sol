// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1155TTL} from "src/ERC1155/extensions/IERC1155TTL.sol";
import {ERC1155TTL} from "src/ERC1155/extensions/ERC1155TTL.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract MockERC1155TTL is ERC1155TTL {
    // This contract is for testing purposes only, so it performs no permission checks

    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        _burnBatch(from, ids, amounts);
    }

    function setTokenTTL(uint256 id, uint256 ttl) external {
        _setTokenTTL(id, ttl);
    }

    function expirationFor(uint256 id) external view returns (uint256) {
        return _expiration(id);
    }

    function maxBalanceRecords() external view returns (uint256) {
        return _maxBalanceRecords();
    }

    function update(address from, address to, uint256[] memory ids, uint256[] memory values) external {
        _update(from, to, ids, values);
    }

    function deductFromBalanceRecords(address from, uint256 id, uint256 amount) external {
        _deductFromBalanceRecords(from, id, amount);
    }

    function transferBalanceRecords(address from, address to, uint256 id, uint256 amount) external {
        _transferBalanceRecords(from, to, id, amount);
    }

    // Helper function to get the underlying ERC1155 balance value
    // This bypasses the ERC1155TTL override and calls the parent contract's balanceOf method
    function getUnderlyingBalance(address owner, uint256 id) external view returns (uint256) {
        return super.balanceOf(owner, id);
    }

    // Helper function to get the length of the balance records array for testing
    function getBalanceRecordsLength(address owner, uint256 id) external view returns (uint256) {
        return _getBalanceRecordsLength(owner, id);
    }
}

contract ERC1155TTLTest is Test {
    MockERC1155TTL public token;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TOKEN_ID_3 = 3;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event ERC1155TTLUpdated(address caller, uint256 indexed id, uint256 ttl);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new MockERC1155TTL();
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155TTL).interfaceId));

        // Test an unsupported interface
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_setTokenTTL() public {
        uint256 ttl = 3600; // 1 hour

        vm.expectEmit(true, true, false, true);
        emit ERC1155TTLUpdated(address(this), TOKEN_ID_1, ttl);

        token.setTokenTTL(TOKEN_ID_1, ttl);

        assertTrue(token.ttlIsSet(TOKEN_ID_1));
        assertEq(token.ttlOf(TOKEN_ID_1), ttl);
    }

    function test_setTokenTTL_alreadyConfigured() public {
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        vm.expectRevert(abi.encodeWithSelector(ERC1155TTL.ERC1155TTLTokenTTLAlreadySet.selector, TOKEN_ID_1, ttl));
        token.setTokenTTL(TOKEN_ID_1, ttl);
    }

    function test_ttlOf_tokenNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155TTL.ERC1155TTLTokenTLLNotSet.selector, TOKEN_ID_1));
        token.ttlOf(TOKEN_ID_1);
    }

    function test_mint_nonExpiringToken() public {
        token.setTokenTTL(TOKEN_ID_1, 0); // Non-expiring

        uint256 amount = 1000;
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);

        token.mint(alice, TOKEN_ID_1, amount, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);
    }

    function test_mint_expiringToken() public {
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 amount = 1000;
        uint256 timestamp = block.timestamp;

        // Calculate actual expiration with bucketing
        uint256 bucketSize = ttl / 30; // 120 seconds
        uint256 actualExpiration = ((timestamp + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), alice, TOKEN_ID_1, amount);

        token.mint(alice, TOKEN_ID_1, amount, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);

        // Fast forward past actual expiration (with bucketing)
        vm.warp(actualExpiration + 1);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_mint_toZeroAddress() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        token.mint(address(0), TOKEN_ID_1, 1000, "");
    }

    function test_safeTransferFrom() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 1000, "");

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(alice, alice, bob, TOKEN_ID_1, 500);

        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 500, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500);
    }

    function test_safeTransferFrom_insufficientBalance() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 500, "");

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 500, 1000, TOKEN_ID_1)
        );
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 1000, "");
    }

    function test_safeTransferFrom_toZeroAddress() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 1000, "");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        token.safeTransferFrom(alice, address(0), TOKEN_ID_1, 500, "");
    }

    function test_safeTransferFrom_withApproval() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 1000, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(bob, alice, charlie, TOKEN_ID_1, 300);

        token.safeTransferFrom(alice, charlie, TOKEN_ID_1, 300, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 700);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), 300);
    }

    function test_safeBatchTransferFrom() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.setTokenTTL(TOKEN_ID_2, 7200);
        
        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500;
        amounts[1] = 1000;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(alice, alice, bob, ids, amounts);

        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 1000);
    }

    function test_safeBatchTransferFrom_withExpiringTokens() public {
        uint256 ttl1 = 3600; // 1 hour
        uint256 ttl2 = 7200; // 2 hours
        
        token.setTokenTTL(TOKEN_ID_1, ttl1);
        token.setTokenTTL(TOKEN_ID_2, ttl2);

        uint256 timestamp = block.timestamp;
        
        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500;
        amounts[1] = 1000;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        // Calculate actual expiration with bucketing for TOKEN_ID_1
        uint256 bucketSize1 = ttl1 / 30; // 120 seconds
        uint256 actualExpiration1 = ((timestamp + ttl1 + bucketSize1 - 1) / bucketSize1) * bucketSize1;

        // Fast forward past first token's expiration
        vm.warp(actualExpiration1 + 1);
        
        // TOKEN_ID_1 should be expired, TOKEN_ID_2 should still be valid
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 1000);
    }

    function test_burn() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 1000, "");

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), alice, address(0), TOKEN_ID_1, 400);

        token.burn(alice, TOKEN_ID_1, 400);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
    }

    function test_burn_insufficientBalance() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 500, "");

        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 500, 1000, TOKEN_ID_1)
        );
        token.burn(alice, TOKEN_ID_1, 1000);
    }

    function test_burnBatch() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.setTokenTTL(TOKEN_ID_2, 7200);
        
        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 400;
        amounts[1] = 800;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), alice, address(0), ids, amounts);

        token.burnBatch(alice, ids, amounts);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 1200);
    }

    function test_setApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);

        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, false);

        token.setApprovalForAll(bob, false);
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_multipleBalanceRecords() public {
        uint256 ttl = 86400; // 24 hours
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Mint tokens at different times
        uint256 baseTime = block.timestamp;
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(baseTime + (i * 3600)); // 1 hour apart
            token.mint(alice, TOKEN_ID_1, 100, "");
        }

        // Check total balance
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);

        // Fast forward and check partial expiration
        vm.warp(baseTime + ttl + 3600); // First batch expired
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 400);

        vm.warp(baseTime + ttl + 7200); // Second batch expired
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 300);
    }

    function test_transferPreservesExpiration() public {
        uint256 ttl = 86400; // 24 hours
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;
        token.mint(alice, TOKEN_ID_1, 1000, "");

        // Calculate the actual expiration with bucketing
        uint256 bucketSize = ttl / 30; // 2880 seconds
        uint256 actualExpiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Transfer half to bob
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 500, "");

        // Fast forward to just before actual expiration
        vm.warp(actualExpiration - 1);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 500);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 500);

        // Fast forward past actual expiration
        vm.warp(actualExpiration + 1);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
    }

    function test_pruneExpiredRecords() public {
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Calculate actual expiration for first batch with bucketing
        uint256 bucketSize = ttl / 30; // 120 seconds
        uint256 firstExpiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        token.mint(alice, TOKEN_ID_1, 100, "");

        vm.warp(baseTime + 1800); // 30 minutes
        token.mint(alice, TOKEN_ID_1, 200, "");

        // Warp past first batch's actual expiration
        vm.warp(firstExpiration + 1);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200);

        // Trigger a mint to verify pruning happens
        token.mint(alice, TOKEN_ID_1, 50, "");
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 250);
    }

    function test_expirationBucketing() public {
        uint256 ttl = 3000; // 50 minutes (with DEFAULT_MAX_BALANCE_RECORDS, bucket size = 100 seconds)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 expiration = token.expirationFor(TOKEN_ID_1);
        uint256 expectedBucketSize = ttl / 30;

        // Expiration should be rounded up to next bucket
        assertTrue(expiration >= block.timestamp + ttl);
        assertTrue(expiration <= block.timestamp + ttl + expectedBucketSize);
    }

    function test_maxBalanceRecordsLimit() public {
        uint256 arraySize = token.maxBalanceRecords();
        uint256 ttl = arraySize; // Very short TTL to create many distinct records
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Try to create more than token.maxBalanceRecords (30) distinct expiration times
        for (uint256 i = 0; i < arraySize; i++) {
            vm.warp(block.timestamp + i + 1);
            token.mint(alice, TOKEN_ID_1, 1, "");
        }

        // Mint number (TTL + 1) should succeed because expired records are pruned automatically
        vm.warp(block.timestamp + ttl + 1);
        token.mint(alice, TOKEN_ID_1, 1, "");

        // Balance should include only non-expired tokens
        assertTrue(token.balanceOf(alice, TOKEN_ID_1) > 0);
    }

    function test_burnFIFO() public {
        uint256 ttl = 86400; // 24 hours
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;
        uint256 increment = ttl / token.maxBalanceRecords(); // 2880 seconds (48 minutes)

        // Mint at different times
        token.mint(alice, TOKEN_ID_1, 100, ""); // Expires first

        vm.warp(baseTime + increment);
        token.mint(alice, TOKEN_ID_1, 200, ""); // Expires second

        vm.warp(baseTime + increment * 2);
        token.mint(alice, TOKEN_ID_1, 300, ""); // Expires third

        // Burn 150 tokens (should consume all of first batch and half of second)
        token.burn(alice, TOKEN_ID_1, 150);

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 450);

        // Fast forward past first expiration
        vm.warp(baseTime + ttl + 1);
        // Should have 150 from second batch and 300 from third
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 450);

        // Fast forward past second expiration
        vm.warp(baseTime + ttl + increment + 1);
        // Second batch hasn't expired yet (expires at baseTime + increment + ttl)
        // We still have 150 from second batch and 300 from third
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 450);
    }

    function test_transferToSelf() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.mint(alice, TOKEN_ID_1, 1000, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, alice, TOKEN_ID_1, 500, "");

        // Balance should remain the same
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);
    }

    function test_combineRecordsWithSameExpiration() public {
        uint256 ttl = 300; // 5 minutes (small bucket size)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Mint multiple times within same bucket
        token.mint(alice, TOKEN_ID_1, 100, "");
        vm.warp(baseTime + 5); // Small time increment
        token.mint(alice, TOKEN_ID_1, 200, "");
        vm.warp(baseTime + 10);
        token.mint(alice, TOKEN_ID_1, 300, "");

        // Should combine into fewer records due to bucketing
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
    }

    function test_verySmallTTL() public {
        // Test with TTL = 1 second (bucketSize would be 0, should default to 1)
        uint256 ttl = 1;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 amount = 100;
        token.mint(alice, TOKEN_ID_1, amount, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), amount);

        // Fast forward 2 seconds - tokens should be expired
        vm.warp(block.timestamp + 2);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_arrayShiftingInUpsert() public {
        // Create a scenario where we need to insert in the middle and shift elements
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Mint at different times to create distinct expiration buckets
        // First mint - earliest expiration
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Third mint - latest expiration (skip second to insert in middle later)
        vm.warp(baseTime + 200);
        token.mint(alice, TOKEN_ID_1, 300, "");

        // Second mint - middle expiration (will require array shifting)
        vm.warp(baseTime + 100);
        token.mint(alice, TOKEN_ID_1, 200, "");

        // Verify all tokens are accounted for
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
    }

    function test_completeRecordTransfer() public {
        // Test transferring entire balance records (not partial)
        uint256 ttl = 86400; // 24 hours
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Mint exact amounts that will be transferred completely
        token.mint(alice, TOKEN_ID_1, 100, "");

        vm.warp(block.timestamp + 3600);
        token.mint(alice, TOKEN_ID_1, 200, "");

        // Transfer exactly 100 tokens (entire first record)
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 100);

        // Transfer exactly 200 tokens (entire second record)
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 200, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 300);
    }

    function test_burnWithInsufficientBalance() public {
        // Test edge case where burn amount calculation has rounding issues
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Mint some tokens
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Calculate actual expiration with bucketing
        uint256 bucketSize = ttl / 30; // 120 seconds
        uint256 actualExpiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Let tokens expire
        vm.warp(actualExpiration + 1);

        // Try to burn the original amount (should fail since all expired)
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, 100, TOKEN_ID_1));
        token.burn(alice, TOKEN_ID_1, 100);
    }

    function test_transferWithInsufficientBalance() public {
        // Test transfer edge case with expired tokens
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Calculate actual expiration with bucketing
        uint256 bucketSize = ttl / 30; // 120 seconds
        uint256 actualExpiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Let tokens expire
        vm.warp(actualExpiration + 1);

        // Try to transfer expired tokens (should fail)
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, 50, TOKEN_ID_1));
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 50, "");
    }

    function test_manyDistinctExpirations() public {
        // Create many distinct expiration times to test array management
        uint256 ttl = 900; // 15 minutes (bucket size = 30 seconds)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Create 10 distinct expiration buckets
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(baseTime + (i * 31)); // Just over bucket size to ensure distinct buckets
            token.mint(alice, TOKEN_ID_1, 10, "");
        }

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);

        // Burn tokens to test FIFO with many records
        token.burn(alice, TOKEN_ID_1, 35); // Should consume first 3.5 records
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 65);

        // Transfer to test record preservation
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 30, "");
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 35);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 30);
    }

    function test_expiration_UnsetTokenTTL() public {
        // Test calling _expiration on a token that has no TTL set
        vm.expectRevert(abi.encodeWithSelector(ERC1155TTL.ERC1155TTLTokenTLLNotSet.selector, TOKEN_ID_3));
        token.expirationFor(TOKEN_ID_3);
    }

    function test_mintToZeroAddressFromZeroAddress() public {
        // Edge case: both from and to are zero in _update
        // This is a theoretical edge case that shouldn't happen in practice
        // but we test it for completeness
        token.setTokenTTL(TOKEN_ID_1, 3600);

        // Direct call to _update with both addresses as zero isn't possible through public interface
        // The contract correctly reverts with ERC1155InvalidReceiver
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        token.mint(address(0), TOKEN_ID_1, 100, "");
    }

    function test_maxBalanceRecordsHandling() public {
        // Test that the contract gracefully handles many distinct expiration times
        // With automatic pruning, MAX_BALANCE_RECORDS errors should not occur
        uint256 ttl = 3600; // 1 hour (bucket size = 120 seconds)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Create 30 distinct expiration times
        for (uint256 i = 0; i < 30; i++) {
            vm.warp(baseTime + (i * 10)); // Create distinct buckets
            token.mint(alice, TOKEN_ID_1, 1, "");
        }

        // All 30 tokens should still be valid (none expired yet)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 30);

        // Adding more should still work due to automatic bucketing
        vm.warp(baseTime + 300);
        token.mint(alice, TOKEN_ID_1, 1, "");

        // Verify tokens are accounted for
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 31);
    }

    function test_complexArrayShiftingWithFullArray() public {
        // Test complex array shifting when array is nearly full
        uint256 ttl = 60; // 1 minute (bucket size = 2 seconds)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Fill 29 slots with alternating pattern to leave gaps for insertion
        for (uint256 i = 0; i < 29; i++) {
            // Create non-sequential expiration times
            uint256 timeIncrement = (i % 2 == 0) ? i * 3 : i * 3 + 50;
            vm.warp(baseTime + timeIncrement);
            token.mint(alice, TOKEN_ID_1, i + 1, "");
        }

        // Now insert in the middle, requiring shifting
        vm.warp(baseTime + 25); // This should fall somewhere in the middle
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Verify total balance
        assertTrue(token.balanceOf(alice, TOKEN_ID_1) > 0);
    }

    function test_insertWithExistingExpirationAfter() public {
        // Test insertion when there's an existing record with later expiration
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Create records with specific expiration order
        token.mint(alice, TOKEN_ID_1, 100, ""); // Early expiration

        vm.warp(baseTime + 300); // Much later
        token.mint(alice, TOKEN_ID_1, 300, ""); // Late expiration

        vm.warp(baseTime + 150); // Middle
        token.mint(alice, TOKEN_ID_1, 200, ""); // Should insert between the two

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
    }

    function test_transferEntireRecordMultiple() public {
        // Test transferring multiple entire records (no partial transfers)
        uint256 ttl = 86400;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Create distinct records with specific amounts
        token.mint(alice, TOKEN_ID_1, 50, "");
        vm.warp(block.timestamp + 1000);
        token.mint(alice, TOKEN_ID_1, 75, "");
        vm.warp(block.timestamp + 1000);
        token.mint(alice, TOKEN_ID_1, 25, "");

        // Transfer exactly the sum of first two records
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 125, ""); // 50 + 75

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 25);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 125);
    }

    function test_insufficientBalanceInBurnRecords() public {
        // This tests the debt > 0 check at the end of _deductFromBalanceRecords
        // This is actually already covered by test_burn_insufficientBalance
        // but we'll create a more specific test
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Try to burn more than balance
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 100, 200, TOKEN_ID_1)
        );
        token.burn(alice, TOKEN_ID_1, 200);
    }

    function test_insufficientBalanceInTransferRecords() public {
        // Test the debt > 0 check in _transferBalanceRecords
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Mint some tokens
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Try to transfer more than balance
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 100, 200, TOKEN_ID_1)
        );
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 200, "");
    }

    function test_minimumBucketSize() public {
        // Test when TTL is so small that bucketSize would be 0
        uint256 ttl = token.maxBalanceRecords() - 1;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        token.mint(alice, TOKEN_ID_1, 100, "");

        // Should still work with bucketSize defaulting to 1
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);

        // Fast forward past expiration
        vm.warp(block.timestamp + ttl + 1);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
    }

    function test_deepArrayShiftingScenario() public {
        // Create a scenario that exercises deep array shifting logic
        uint256 ttl = 120; // 2 minutes (bucket size = 4 seconds)
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Create a pattern that will require shifting
        // Fill positions 0, 2, 4, 6, 8 (leaving gaps)
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(baseTime + (i * 10));
            token.mint(alice, TOKEN_ID_1, 10, "");
        }

        // Now fill the gaps in reverse order to trigger shifting
        for (uint256 i = 4; i > 0; i--) {
            vm.warp(baseTime + (i * 10) - 5); // Insert between existing records
            token.mint(alice, TOKEN_ID_1, 5, "");
        }

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 70); // 5*10 + 4*5
    }

    function test_updateFromZeroAddressToZeroAddress() public {
        // Test calling _update directly with both `from` and `to` as zero addresses
        // When both from and to are zero, it returns early due to from == to check
        // and calls super._update which should handle it appropriately (no revert expected)
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory values = new uint256[](1);
        values[0] = 100;

        // This should not revert because from == to triggers early return
        token.update(address(0), address(0), ids, values);
    }

    function test_deductFromBalanceRecordsWithInsufficientBalance() public {
        // Test calling _deductFromBalanceRecords directly with insufficient balance
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);

        token.mint(alice, TOKEN_ID_1, 100, "");

        // Try to burn more than balance
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 100, 200, TOKEN_ID_1)
        );
        token.deductFromBalanceRecords(alice, TOKEN_ID_1, 200);
    }

    function test_transferBalanceRecordsWithInsufficientBalance() public {
        // Test calling _transferBalanceRecords directly with insufficient balance
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);

        token.mint(alice, TOKEN_ID_1, 100, "");

        // Try to transfer more than balance
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 100, 200, TOKEN_ID_1)
        );
        token.transferBalanceRecords(alice, bob, TOKEN_ID_1, 200);
    }

    // ============ Underlying Balance Sync Tests ============
    // These tests verify that balanceOf and super.balanceOf always return the same value
    // The underlying ERC1155 balance should match the unexpired balance records

    function test_underlyingBalanceSyncWithMinting() public {
        // Test that both balances stay in sync during minting
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Initial state - both should be 0
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);

        // Mint tokens - both should be 100
        token.mint(alice, TOKEN_ID_1, 100, "");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 100);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);
        // They should match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));

        // Mint more - both should be 150
        token.mint(alice, TOKEN_ID_1, 50, "");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 150);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 150);
        // They should still match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
    }

    function test_underlyingBalanceSyncWithExpiration() public {
        // Test that both balances reflect expiration the same way
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Mint tokens
        token.mint(alice, TOKEN_ID_1, 100, "");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 100);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 100);

        // Calculate actual expiration
        uint256 bucketSize = ttl / 30;
        uint256 expiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Warp past expiration
        vm.warp(expiration + 1);

        // Both balances should show 0 (expired tokens not counted)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0, "balanceOf should be 0 after expiration");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 0, "super.balanceOf should also be 0");

        // They should match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
    }

    function test_underlyingBalanceSyncWithBurning() public {
        // Test that burning updates both balances correctly
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        token.mint(alice, TOKEN_ID_1, 200, "");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 200);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200);

        // Burn some tokens
        token.burn(alice, TOKEN_ID_1, 50);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 150);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 150);

        // Burn more
        token.burn(alice, TOKEN_ID_1, 100);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 50);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 50);
    }

    function test_underlyingBalanceSyncWithTransfers() public {
        // Test that transfers update underlying balances correctly
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        token.mint(alice, TOKEN_ID_1, 300, "");

        // Check initial state
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 300);
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), 0);

        // Transfer
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");

        // Both underlying balances should be updated
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 200);
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), 100);

        // And should match non-expired balances
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 100);
    }

    function test_underlyingBalanceWithPartialExpiration() public {
        // Test complex scenario with partial expiration
        uint256 ttl = 3600;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 baseTime = block.timestamp;

        // Mint in batches
        token.mint(alice, TOKEN_ID_1, 100, "");

        vm.warp(baseTime + 1800); // 30 minutes later
        token.mint(alice, TOKEN_ID_1, 200, "");

        // Both balances should be 300
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 300);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 300);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));

        // Calculate first batch expiration
        uint256 bucketSize = ttl / 30;
        uint256 firstExpiration = ((baseTime + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Warp past first expiration
        vm.warp(firstExpiration + 1);

        // Both balances should show 200 (first batch expired)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 200, "balanceOf should be 200");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 200, "super.balanceOf should also be 200");
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));

        // Now burn the remaining valid tokens
        token.burn(alice, TOKEN_ID_1, 200);

        // Both balances should be 0 (all tokens burned)
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 0);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
    }

    function test_underlyingBalanceInvariant() public {
        // Test the invariant: balanceOf and super.balanceOf should always match
        // And sum of all balances = total unexpired tokens
        uint256 ttl = 7200;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 totalMinted = 0;
        uint256 totalBurned = 0;

        // Mint to multiple users
        token.mint(alice, TOKEN_ID_1, 500, "");
        totalMinted += 500;

        token.mint(bob, TOKEN_ID_1, 300, "");
        totalMinted += 300;

        token.mint(charlie, TOKEN_ID_1, 200, "");
        totalMinted += 200;

        // Verify balances match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), token.balanceOf(bob, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(charlie, TOKEN_ID_1), token.balanceOf(charlie, TOKEN_ID_1));

        // Verify total
        uint256 totalBalance =
            token.balanceOf(alice, TOKEN_ID_1) + token.balanceOf(bob, TOKEN_ID_1) + token.balanceOf(charlie, TOKEN_ID_1);
        assertEq(totalBalance, totalMinted - totalBurned);

        // Perform some transfers (shouldn't affect total)
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 100, "");

        vm.prank(bob);
        token.safeTransferFrom(bob, charlie, TOKEN_ID_1, 50, "");

        // Verify balances still match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), token.balanceOf(bob, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(charlie, TOKEN_ID_1), token.balanceOf(charlie, TOKEN_ID_1));

        // Burn some tokens
        token.burn(alice, TOKEN_ID_1, 200);
        totalBurned += 200;

        token.burn(bob, TOKEN_ID_1, 150);
        totalBurned += 150;

        // Verify balances still match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), token.balanceOf(alice, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), token.balanceOf(bob, TOKEN_ID_1));
        assertEq(token.getUnderlyingBalance(charlie, TOKEN_ID_1), token.balanceOf(charlie, TOKEN_ID_1));

        totalBalance =
            token.balanceOf(alice, TOKEN_ID_1) + token.balanceOf(bob, TOKEN_ID_1) + token.balanceOf(charlie, TOKEN_ID_1);
        assertEq(totalBalance, totalMinted - totalBurned);

        // After expiration, both balances should reflect it
        vm.warp(block.timestamp + ttl + 1000);

        // All tokens should be expired, so all balances should be 0
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(charlie, TOKEN_ID_1), 0);

        // And underlying should match
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 0);
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), 0);
        assertEq(token.getUnderlyingBalance(charlie, TOKEN_ID_1), 0);
    }

    function test_underlyingBalanceWithNonExpiringTokens() public {
        // Test with non-expiring tokens (TTL = 0)
        token.setTokenTTL(TOKEN_ID_1, 0); // Non-expiring

        token.mint(alice, TOKEN_ID_1, 1000, "");

        // Both balances should always match for non-expiring tokens
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);

        // Even after time passes
        vm.warp(block.timestamp + 365 days);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);

        // After transfers
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, TOKEN_ID_1, 400, "");

        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 600);
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 600);
        assertEq(token.getUnderlyingBalance(bob, TOKEN_ID_1), 400);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 400);
    }

    function test_insertMiddleWithEmptySlotSearch() public {
        // This test targets the uncovered break statement on line 150
        // We need insertion between existing records that requires shifting

        // Use very small TTL for many distinct buckets
        token.setTokenTTL(TOKEN_ID_1, 300); // 5 minutes, bucket size = 10 seconds

        uint256 baseTime = block.timestamp;

        // Create initial records at specific bucket boundaries
        // Bucket 1 (expires at 10)
        vm.warp(baseTime + 1);
        token.mint(alice, TOKEN_ID_1, 100, "");

        // Bucket 5 (expires at 50) - skip buckets 2,3,4
        vm.warp(baseTime + 41);
        token.mint(alice, TOKEN_ID_1, 200, "");

        // Bucket 10 (expires at 100) - skip buckets 6,7,8,9
        vm.warp(baseTime + 91);
        token.mint(alice, TOKEN_ID_1, 300, "");

        // Now we have 3 records at indices 0,1,2 with specific expirations
        // Indices 3-29 are empty

        // Insert at bucket 7 (expires at 70) - between buckets 5 and 10
        vm.warp(baseTime + 61);
        token.mint(alice, TOKEN_ID_1, 150, "");

        // This should insert at index 2, shifting the bucket 10 record to index 3
        // The search will find empty slot at index 3 and break

        // Verify all tokens are accounted for
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 750);
        assertEq(token.getUnderlyingBalance(alice, TOKEN_ID_1), 750);
    }

    function test_arrayShrinkingWhenLargeAndHalfEmpty() public {
        // Test the array shrinking logic when less than half is used and array is large
        // The shrinking occurs when: currentLength > writeIndex * 2 && currentLength > 10

        uint256 ttl = 20;
        token.setTokenTTL(TOKEN_ID_1, ttl);

        uint256 maxRecords = token.maxBalanceRecords();
        uint256 recordsToCreate = maxRecords / 2 + 1; // Create just over half of max records

        // Create records with different expiration times
        // Each mint happens 1 second apart to ensure different expiration buckets
        uint256 startTime = block.timestamp;
        for (uint256 i = 0; i < recordsToCreate; i++) {
            vm.warp(startTime + i);
            token.mint(alice, TOKEN_ID_1, 10, "");
        }

        // Verify the array has the expected number of records
        uint256 initialLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(initialLength, recordsToCreate, "Initial array length should match records created");

        // Now wait for all records to expire
        vm.warp(startTime + ttl + recordsToCreate + 1);

        // At this point, all records have expired
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0, "All tokens should have expired");

        // Trigger pruning by minting a new token
        // This will call _pruneBalanceRecords which should detect that:
        // 1. All existing records are expired (writeIndex will be 0)
        // 2. currentLength > 10 (we have 16 records)
        // 3. currentLength > writeIndex * 2 (16 > 0 * 2)
        // Therefore it should clear the entire array
        token.mint(alice, TOKEN_ID_1, 5, "");

        // Check that the array was shrunk
        uint256 finalLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(finalLength, 1, "Array should be shrunk to just the new record");

        // Verify the balance is correct
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 5, "Balance should be the newly minted amount");
    }

    function test_arrayShrinkingAllRecordsInvalid() public {
        // Test complete array clearing when all records are invalid
        // This tests the condition: writeIndex == 0 && currentLength > 0

        uint256 ttl = 10; // 10 seconds
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Create some records
        token.mint(alice, TOKEN_ID_1, 100, "");
        vm.warp(block.timestamp + 1);
        token.mint(alice, TOKEN_ID_1, 200, "");
        vm.warp(block.timestamp + 1);
        token.mint(alice, TOKEN_ID_1, 300, "");

        // Verify we have 3 records
        uint256 initialLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(initialLength, 3, "Should have 3 records initially");

        // Wait for all to expire
        vm.warp(block.timestamp + ttl + 10);

        // Balance should be 0 since all expired
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0, "All tokens should have expired");

        // Trigger pruning by minting a new token
        // This will detect all records are invalid (writeIndex = 0) and clear the array
        token.mint(alice, TOKEN_ID_1, 50, "");

        // Check that the array was completely cleared and rebuilt with just the new record
        uint256 finalLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(finalLength, 1, "Array should be cleared and have just the new record");

        // Verify the balance is correct
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 50, "Balance should be the newly minted amount");
    }

    function test_arrayShrinkingPartiallyUsed() public {
        // Test partial array shrinking when less than half is used
        // This specifically tests: currentLength > writeIndex * 2 && currentLength > 10

        uint256 ttl = 30; // 30 seconds TTL
        token.setTokenTTL(TOKEN_ID_1, ttl);

        // Create exactly 12 records (need > 10 for shrinking to be considered)
        uint256 startTime = block.timestamp;
        for (uint256 i = 0; i < 12; i++) {
            vm.warp(startTime + i);
            token.mint(alice, TOKEN_ID_1, 10 + i, ""); // Different amounts for tracking
        }

        // Verify initial array length
        uint256 initialLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(initialLength, 12, "Should have 12 records initially");

        // Now expire most records, keeping only 5 valid (less than half of 12)
        // Records 0-6 will expire, records 7-11 will remain valid
        vm.warp(startTime + 7 + ttl - 1);
        uint256 halfExpiredLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertEq(halfExpiredLength, 12, "Array length should still be 12 before pruning");

        // Trigger pruning - this should shrink the array
        // After pruning: writeIndex = 5, currentLength = 12
        // Condition: 12 > 5 * 2 (true) && 12 > 10 (true) => should shrink
        token.mint(alice, TOKEN_ID_1, 100, "");

        // The array should be shrunk to approximately the number of valid records
        uint256 finalLength = token.getBalanceRecordsLength(alice, TOKEN_ID_1);
        assertLe(finalLength, 6, "Array should be shrunk to approximately valid records + 1");
        assertGe(finalLength, 5, "Array should have at least the valid records");

        // Verify balance is correct (5 records of 17-21 + new 100)
        uint256 expectedBalance = 17 + 18 + 19 + 20 + 21 + 100; // = 195
        assertEq(token.balanceOf(alice, TOKEN_ID_1), expectedBalance, "Balance should be correct after pruning");
    }

    // ============ Batch Operation Tests ============
    // These tests focus on batch operations specific to ERC1155

    function test_mintBatch() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.setTokenTTL(TOKEN_ID_2, 7200);

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000;
        amounts[1] = 2000;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), alice, ids, amounts);

        token.mintBatch(alice, ids, amounts, "");

        assertEq(token.balanceOf(alice, TOKEN_ID_1), 1000);
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 2000);
    }

    function test_burnBatch_insufficientBalance() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.setTokenTTL(TOKEN_ID_2, 7200);

        token.mint(alice, TOKEN_ID_1, 500, "");
        token.mint(alice, TOKEN_ID_2, 1000, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000; // More than balance
        amounts[1] = 500;

        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 500, 1000, TOKEN_ID_1)
        );
        token.burnBatch(alice, ids, amounts);
    }

    function test_safeBatchTransferFrom_withExpiration() public {
        uint256 ttl1 = 3600; // 1 hour
        uint256 ttl2 = 7200; // 2 hours
        
        token.setTokenTTL(TOKEN_ID_1, ttl1);
        token.setTokenTTL(TOKEN_ID_2, ttl2);

        uint256 timestamp = block.timestamp;
        
        // Mint tokens at the same time
        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500;
        amounts[1] = 1000;

        // Transfer batch
        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        // Calculate actual expiration with bucketing for TOKEN_ID_1
        uint256 bucketSize1 = ttl1 / 30; // 120 seconds
        uint256 actualExpiration1 = ((timestamp + ttl1 + bucketSize1 - 1) / bucketSize1) * bucketSize1;

        // Fast forward past first token's expiration but before second
        vm.warp(actualExpiration1 + 1);
        
        // TOKEN_ID_1 should be expired for both alice and bob
        assertEq(token.balanceOf(alice, TOKEN_ID_1), 0);
        assertEq(token.balanceOf(bob, TOKEN_ID_1), 0);
        
        // TOKEN_ID_2 should still be valid for both
        assertEq(token.balanceOf(alice, TOKEN_ID_2), 1000);
        assertEq(token.balanceOf(bob, TOKEN_ID_2), 1000);
    }

    function test_balanceOfBatch() public {
        token.setTokenTTL(TOKEN_ID_1, 3600);
        token.setTokenTTL(TOKEN_ID_2, 7200);

        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");
        token.mint(bob, TOKEN_ID_1, 500, "");
        token.mint(bob, TOKEN_ID_2, 1500, "");

        address[] memory accounts = new address[](4);
        accounts[0] = alice;
        accounts[1] = alice;
        accounts[2] = bob;
        accounts[3] = bob;

        uint256[] memory ids = new uint256[](4);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        ids[2] = TOKEN_ID_1;
        ids[3] = TOKEN_ID_2;

        uint256[] memory balances = token.balanceOfBatch(accounts, ids);

        assertEq(balances[0], 1000); // alice TOKEN_ID_1
        assertEq(balances[1], 2000); // alice TOKEN_ID_2
        assertEq(balances[2], 500);  // bob TOKEN_ID_1
        assertEq(balances[3], 1500); // bob TOKEN_ID_2
    }

    function test_balanceOfBatch_withExpiredTokens() public {
        uint256 ttl = 3600; // 1 hour
        token.setTokenTTL(TOKEN_ID_1, ttl);
        token.setTokenTTL(TOKEN_ID_2, 0); // Non-expiring

        uint256 timestamp = block.timestamp;

        token.mint(alice, TOKEN_ID_1, 1000, "");
        token.mint(alice, TOKEN_ID_2, 2000, "");

        // Calculate actual expiration with bucketing
        uint256 bucketSize = ttl / 30; // 120 seconds
        uint256 actualExpiration = ((timestamp + ttl + bucketSize - 1) / bucketSize) * bucketSize;

        // Fast forward past TOKEN_ID_1 expiration
        vm.warp(actualExpiration + 1);

        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = alice;

        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;

        uint256[] memory balances = token.balanceOfBatch(accounts, ids);

        assertEq(balances[0], 0);    // alice TOKEN_ID_1 (expired)
        assertEq(balances[1], 2000); // alice TOKEN_ID_2 (non-expiring)
    }
}