// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { BaseTest } from "test/_helpers/BaseTest.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenEphemeralV1 is TokenEphemeral, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function initialize(address initialOwner) public initializer {
        __MockTokenEphemeralV1_init(initialOwner);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function __MockTokenEphemeralV1_init(address initialOwner) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __TokenEphemeral_init();
        __MockTokenEphemeralV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockTokenEphemeralV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not authorized.
    }

    // @dev Expose internal function for testing
    function setTTL(uint256 id, uint48 ttl) public onlyOwner {
        _setTTL(id, ttl);
    }

    // @dev Expose internal function for testing
    function expiresAt(uint256 id) public view returns (uint256) {
        return _expiresAt(id);
    }

    // @dev Expose internal function for testing
    function maxBalanceRecords() public view returns (uint256) {
        return _maxBalanceRecords();
    }

    // @dev Helper function to mint tokens for testing.
    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _updateBalanceRecords(address(0), to, id, amount);
    }

    // @dev Helper function to burn tokens for testing.
    function burn(address from, uint256 id, uint256 amount) external onlyOwner {
        _updateBalanceRecords(from, address(0), id, amount);
    }

    // @dev Helper function to transfer tokens for testing.
    function transfer(address to, uint256 id, uint256 amount) external {
        _updateBalanceRecords(_msgSender(), to, id, amount);
    }
}

contract TokenEphemeralTest is BaseTest {
    MockTokenEphemeralV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenEphemeralV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "TokenEphemeral.t.sol:MockTokenEphemeralV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenEphemeralV1.initialize, (owner));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockTokenEphemeralV1(proxyAddress);
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertEq(v1.tokenTTL(1), 0);

        // Check that the storage slot for TokenEphemeral is correctly calculated to avoid storage collisions.
        assertEq(
            0xec3c1253ecdf88a29ff53024f0721fc3faa1b42abcff612deb5b22d1f94e2d00,
            keccak256(abi.encode(uint256(keccak256("tokenephemeral.storage.TokenEphemeral")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }

    function test_balanceOf_succeeds() public {
        // Set TTL for token ID 1 to 10 seconds.
        vm.prank(owner);
        v1.setTTL(1, 10);

        // Verify expiration time.
        uint256 expiresAt = v1.expiresAt(1);
        assertEq(expiresAt, block.timestamp + 10);

        // Mint a token with a TTL of 10 seconds.
        vm.prank(owner);
        v1.mint(alice, 1, 1);
        assertEq(v1.balanceOf(alice, 1), 1);

        // Fast forward time by 5 seconds; the token should still be valid.
        vm.warp(block.timestamp + 5);
        assertEq(v1.balanceOf(alice, 1), 1);

        // Fast forward time by another 6 seconds (total 11 seconds); the token should have expired.
        vm.warp(block.timestamp + 6);
        assertEq(v1.balanceOf(alice, 1), 0);
    }

    function test_balanceOf_multipleTokens() public {
        // Set TTLs for token IDs.
        vm.startPrank(owner);
        v1.setTTL(1, 10); // Token ID 1 with TTL 10 seconds
        v1.setTTL(2, 20); // Token ID 2 with TTL 20 seconds
        vm.stopPrank();

        // Verify expiration for token ID 1.
        uint256 expiresAt = v1.expiresAt(1);
        assertEq(expiresAt, block.timestamp + 10);

        // Verify expiration for token ID 2.
        expiresAt = v1.expiresAt(2);
        assertEq(expiresAt, block.timestamp + 20);

        // Mint multiple tokens with different TTLs.
        vm.startPrank(owner);
        v1.mint(alice, 1, 1);
        v1.mint(alice, 2, 1);
        vm.stopPrank();

        // Verify Alice's balances immediately after minting.
        assertEq(v1.balanceOf(alice, 1), 1);
        assertEq(v1.balanceOf(alice, 2), 1);

        // Fast forward time by 15 seconds; Token ID 1 should have expired, Token ID 2 should still be valid.
        vm.warp(block.timestamp + 15);
        assertEq(v1.balanceOf(alice, 1), 0);
        assertEq(v1.balanceOf(alice, 2), 1);

        // Fast forward time by another 10 seconds (total 25 seconds); both tokens should have expired.
        vm.warp(block.timestamp + 10);
        assertEq(v1.balanceOf(alice, 1), 0);
        assertEq(v1.balanceOf(alice, 2), 0);
    }

    function test_balanceRecordsOf_succeeds() public {
        // Verify Alice has no balance records initially.
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 0);
        records = v1.balanceRecordsOf(alice, 2);
        assertEq(records.length, 0);

        // Set TTLs for token IDs.
        vm.startPrank(owner);
        v1.setTTL(1, 10); // Token ID 1 with TTL 10 seconds
        v1.setTTL(2, 20); // Token ID 2 with TTL 20 seconds
        vm.stopPrank();

        // Verify expiration for token ID 1.
        uint256 expiresAt = v1.expiresAt(1);
        assertEq(expiresAt, block.timestamp + 10);

        // Verify expiration for token ID 2.
        expiresAt = v1.expiresAt(2);
        assertEq(expiresAt, block.timestamp + 20);

        // Mint multiple tokens with different TTLs.
        vm.startPrank(owner);
        v1.mint(alice, 1, 1);
        v1.mint(alice, 2, 1);
        vm.stopPrank();

        // Verify Alice's balance records for Token ID 1.
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 1);
        assertEq(records[0].expiresAt, block.timestamp + 10);

        // Verify Alice's balance records for Token ID 2.
        records = v1.balanceRecordsOf(alice, 2);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 1);
        assertEq(records[0].expiresAt, block.timestamp + 20);

        // Fast forward time by 15 seconds.
        vm.warp(block.timestamp + 15);

        // Token ID 1 should have expired, but the record was not pruned so it should still exist.
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 1);
        assertEq(records[0].expiresAt, block.timestamp - 5); // Expired

        // Token ID 2 should still be valid with 5 seconds remaining.
        records = v1.balanceRecordsOf(alice, 2);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 1);
        assertEq(records[0].expiresAt, block.timestamp + 5);
    }

    function test_balanceRecordsOf_afterPruning() public {
        // Verify Alice has no balance records initially.
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 0);

        // Set TTL for token ID 1.
        vm.prank(owner);
        v1.setTTL(1, 10); // Token ID 1 with TTL 10 seconds

        // Verify expiration for token ID 1.
        uint256 expiresAt = v1.expiresAt(1);
        assertEq(expiresAt, block.timestamp + 10);

        // Mint a token with TTL.
        vm.prank(owner);
        v1.mint(alice, 1, 1);

        // Verify Alice's balance records for Token ID 1.
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 1);
        assertEq(records[0].expiresAt, block.timestamp + 10);

        // Fast forward time by 15 seconds to let the token expire.
        vm.warp(block.timestamp + 15);

        // Prune expired balance records.
        vm.prank(alice);
        v1.pruneBalanceRecords(alice, 1);

        // Verify Alice's balance records for Token ID 1 after pruning.
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 0); // All records should be pruned
    }

    function testFuzz_balanceRecordsOf_maxArraySize(uint256 tokenId, uint48 ttl, uint256 amount) public {
        // Bound TTL to a reasonable value
        ttl = uint48(bound(ttl, 1, 365 days));

        // Bound amount to prevent overflow in calculations
        amount = bound(amount, 1, 100);

        // Ensure we mint more than the max balance records
        uint256 maxRecords = v1.maxBalanceRecords();
        uint256 numMints = maxRecords * 2;

        // Set token TTL
        vm.prank(owner);
        v1.setTTL(tokenId, ttl);

        // Mint tokens at different timestamps to create multiple balance records
        for (uint256 i = 0; i < numMints; i++) {
            // Advance time by at least bucket size, to ensure different expiration buckets
            uint256 bucketSize = ttl / maxRecords;
            if (bucketSize == 0) bucketSize = 1;
            vm.warp(block.timestamp + bucketSize + i);

            // Mint some amount of tokens
            vm.prank(owner);
            v1.mint(alice, tokenId, amount);

            // Check that balance records never exceed max plus one (for the current bucket)
            TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, tokenId);
            assertLe(records.length, maxRecords + 1, "Balance records should never exceed maxBalanceRecords");
        }
    }

    function testFuzz_setTTL_succeeds(uint256 tokenId, uint48 ttl) public {
        // Bound TTL to reasonable values to avoid overflow
        ttl = uint48(bound(ttl, 0, type(uint48).max));

        // Set the token TTL
        vm.prank(owner);
        v1.setTTL(tokenId, ttl);

        // Verify the TTL was set correctly
        uint256 result = v1.tokenTTL(tokenId);
        assertEq(result, ttl, "Token TTL should match the set value");
    }

    function testFuzz_expiresAt_permanentTokens(uint256 tokenId, uint256 timestamp) public {
        // Bound timestamp to reasonable values to avoid overflow
        timestamp = bound(timestamp, 1, type(uint128).max);

        // Set the block timestamp and token TTL to 0 (permanent)
        vm.warp(timestamp);
        assertEq(v1.tokenTTL(tokenId), 0);

        // Verify that permanent tokens return max uint256
        uint256 result = v1.expiresAt(tokenId);
        assertEq(result, type(uint256).max, "Permanent tokens should return max uint256");
    }

    function testFuzz_expiresAt_oneSecondTimeBuckets(uint256 tokenId, uint48 ttl, uint256 timestamp) public {
        // Ensure TTL is greater than zero but no more than maxBalanceRecords, to force bucket size of 1 second
        ttl = uint48(bound(ttl, 1, v1.maxBalanceRecords()));

        // Bound to prevent overflow in calculations
        timestamp = bound(timestamp, 1, type(uint64).max);

        // Set the block timestamp and token TTL
        vm.warp(timestamp);
        vm.prank(owner);
        v1.setTTL(tokenId, ttl);

        // For small TTLs, the bucket size will be 1 second, so expiration should be exact
        uint256 result = v1.expiresAt(tokenId);
        assertEq(result, block.timestamp + ttl, "Result should equal minimum expiration when bucket size is 1");
    }

    function testFuzz_expiresAt_largerTimeBuckets(uint256 tokenId, uint48 ttl, uint256 timestamp) public {
        // Ensure TTL is greater than twice maxBalanceRecords, to ensure a bucket size of at least 2 seconds
        ttl = uint48(bound(ttl, v1.maxBalanceRecords() * 2, type(uint48).max));

        // Bound to prevent overflow in calculations
        timestamp = bound(timestamp, 1, type(uint64).max);

        // Set the block timestamp and token TTL
        vm.warp(timestamp);
        vm.prank(owner);
        v1.setTTL(tokenId, ttl);

        // Calculate expected expiration range based on bucket size
        uint256 bucketSize = ttl / v1.maxBalanceRecords();
        uint256 minimumExpiration = block.timestamp + ttl;
        uint256 maximumExpiration = block.timestamp + ttl + bucketSize - 1;

        // Verify the expiration falls within the expected range
        uint256 result = v1.expiresAt(tokenId);
        assertGe(result, minimumExpiration, "Result should be greater than or equal to minimum expiration");
        assertLe(result, maximumExpiration, "Result should be less than or equal to maximum expiration");
    }

    function test_addToBalanceRecords_permanentTokens() public {
        // Token with 0 TTL should be permanent
        assertEq(v1.tokenTTL(1), 0);

        // Mint permanent tokens
        vm.startPrank(owner);
        v1.mint(alice, 1, 100);
        v1.mint(alice, 1, 200);
        vm.stopPrank();

        // Should have one record with max expiration
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 300);
        assertEq(records[0].expiresAt, type(uint256).max);

        // Balance should not expire even after long time
        vm.warp(block.timestamp + (60 * 60 * 24 * 365 * 99)); // 99 years
        assertEq(v1.balanceOf(alice, 1), 300);
    }

    function test_addToBalanceRecords_sameTimeBucket() public {
        // Set TTL for token ID 1
        vm.prank(owner);
        v1.setTTL(1, 60 * 60); // 1 hour

        uint256 expiresAt = v1.expiresAt(1);

        // Mint multiple times at same timestamp (same expiration bucket)
        vm.startPrank(owner);
        v1.mint(alice, 1, 10);
        vm.warp(block.timestamp + 1); // Still within same bucket
        v1.mint(alice, 1, 20);
        vm.warp(block.timestamp + 1); // Still within same bucket
        v1.mint(alice, 1, 30);
        vm.stopPrank();

        // Should have only one record with combined amount
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 1);
        assertEq(records[0].amount, 60);
        assertEq(records[0].expiresAt, expiresAt);
        assertEq(v1.balanceOf(alice, 1), 60);
    }

    function test_deductFromBalanceRecords_exactAmount() public {
        // Set TTL and mint tokens
        vm.prank(owner);
        v1.setTTL(1, 100);

        vm.prank(owner);
        v1.mint(alice, 1, 100);

        // Burn exact amount
        vm.prank(owner);
        v1.burn(alice, 1, 100);

        assertEq(v1.balanceOf(alice, 1), 0);
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 0);
    }

    function test_deductFromBalanceRecords_FIFO() public {
        // Set TTL and create multiple balance records
        vm.prank(owner);
        v1.setTTL(1, 60 * 60); // 1 hour

        // Mint at different times
        uint256 bucketSize = v1.tokenTTL(1) / v1.maxBalanceRecords();
        vm.startPrank(owner);
        v1.mint(alice, 1, 10);
        vm.warp(block.timestamp + bucketSize + 1);
        v1.mint(alice, 1, 20);
        vm.warp(block.timestamp + bucketSize + 1);
        v1.mint(alice, 1, 30);
        vm.stopPrank();

        // Verify initial state
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 3);
        assertEq(records[0].amount, 10);
        assertEq(records[1].amount, 20);
        assertEq(records[2].amount, 30);
        assertEq(v1.balanceOf(alice, 1), 60);

        // Burn 15 tokens - should consume all 10 from first record and 5 from second
        vm.prank(owner);
        v1.burn(alice, 1, 15); // Burning automatically prunes balance records afterwards

        // Verify state after burn
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 3); // Array should be compacted, with empty slots pushed to the end
        assertEq(records[0].amount, 15); // Second record partially consumed (20-5)
        assertEq(records[1].amount, 30); // Third record untouched
        assertEq(records[2].amount, 0); // First record fully consumed, pushed to the end of the array
        assertEq(v1.balanceOf(alice, 1), 45);
    }

    function testRevert_deductFromBalanceRecords_InsufficientBalance() public {
        // Set TTL and mint tokens
        vm.prank(owner);
        v1.setTTL(1, 60 * 60 * 24); // 1 day

        vm.prank(owner);
        v1.mint(alice, 1, 50);

        // Try to burn more than available
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenEphemeral.InsufficientBalance.selector,
                alice,
                50, // available
                100, // requested
                1 // token id
            )
        );
        v1.burn(alice, 1, 100);
    }

    function testRevert_deductFromBalanceRecords_InsufficientBalance_allExpired() public {
        // Set TTL
        vm.prank(owner);
        v1.setTTL(1, 10);

        // Mint tokens at different times
        vm.prank(owner);
        v1.mint(alice, 1, 10);

        // Let tokens expire
        vm.warp(block.timestamp + 20);

        // Try to burn tokens after they have expired
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenEphemeral.InsufficientBalance.selector,
                alice,
                0, // available (all expired)
                5, // requested
                1 // token id
            )
        );
        v1.burn(alice, 1, 5);
    }

    function testRevert_deductFromBalanceRecords_InsufficientBalance_someExpired() public {
        // Set TTL
        vm.prank(owner);
        v1.setTTL(1, 60);

        // Mint tokens
        vm.prank(owner);
        v1.mint(alice, 1, 10);
        vm.warp(block.timestamp + 10); // Advance time but not enough to expire
        vm.prank(owner);
        v1.mint(alice, 1, 10);

        // Let first tokens expire
        vm.warp(block.timestamp + 60);

        // Try to burn tokens after they have expired
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenEphemeral.InsufficientBalance.selector,
                alice,
                10, // available (only second batch)
                15, // requested
                1 // token id
            )
        );
        v1.burn(alice, 1, 15);
    }

    function test_transferBalanceRecords_preservesExpiration() public {
        // Set TTL
        vm.prank(owner);
        v1.setTTL(1, 100);

        // Mint tokens to Alice
        vm.prank(owner);
        v1.mint(alice, 1, 50);
        uint256 originalExpiry = v1.expiresAt(1);

        // Transfer to Bob
        vm.prank(alice);
        v1.transfer(bob, 1, 30);

        // Check Alice's remaining balance
        TokenEphemeral.BalanceRecord[] memory aliceRecords = v1.balanceRecordsOf(alice, 1);
        assertEq(aliceRecords.length, 1);
        assertEq(aliceRecords[0].amount, 20);
        assertEq(aliceRecords[0].expiresAt, originalExpiry);

        // Check Bob received tokens with same expiration
        TokenEphemeral.BalanceRecord[] memory bobRecords = v1.balanceRecordsOf(bob, 1);
        assertEq(bobRecords.length, 1);
        assertEq(bobRecords[0].amount, 30);
        assertEq(bobRecords[0].expiresAt, originalExpiry);
    }

    function test_transferBalanceRecords_FIFO() public {
        // Set TTL for bucketing
        vm.prank(owner);
        v1.setTTL(1, 60 * 60); // 1 hour

        // Mint tokens to Alice at different times
        uint256 bucketSize = v1.tokenTTL(1) / v1.maxBalanceRecords();
        vm.startPrank(owner);
        uint256 firstBalanceRecordExpiresAt = v1.expiresAt(1);
        v1.mint(alice, 1, 10);
        vm.warp(block.timestamp + bucketSize + 1);
        uint256 secondBalanceRecordExpiresAt = v1.expiresAt(1);
        v1.mint(alice, 1, 20);
        vm.warp(block.timestamp + bucketSize + 1);
        v1.mint(alice, 1, 30);
        vm.stopPrank();

        // Transfer 25 tokens from Alice to Bob (10 from first record, 15 from second)
        vm.prank(alice);
        v1.transfer(bob, 1, 25);

        // Check Alice's remaining balances
        TokenEphemeral.BalanceRecord[] memory aliceRecords = v1.balanceRecordsOf(alice, 1);
        assertEq(aliceRecords.length, 3); // Array should be compacted, with empty slots pushed to the end
        assertEq(aliceRecords[0].amount, 5); // Second record partially consumed
        assertEq(aliceRecords[1].amount, 30); // Third record untouched
        assertEq(aliceRecords[2].amount, 0); // First record fully consumed, pushed to the end of the array

        // Check Bob received correct tokens with correct expirations
        TokenEphemeral.BalanceRecord[] memory bobRecords = v1.balanceRecordsOf(bob, 1);
        assertEq(bobRecords.length, 2);
        assertEq(bobRecords[0].amount, 10);
        assertEq(bobRecords[0].expiresAt, firstBalanceRecordExpiresAt);
        assertEq(bobRecords[1].amount, 15);
        assertEq(bobRecords[1].expiresAt, secondBalanceRecordExpiresAt);
    }

    function testRevert_transferBalanceRecords_InsufficientBalance() public {
        // Set TTL and mint tokens
        vm.prank(owner);
        v1.setTTL(1, 100);

        vm.prank(owner);
        v1.mint(alice, 1, 50);

        // Try to transfer more than available
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenEphemeral.InsufficientBalance.selector,
                alice,
                50, // available
                100, // requested
                1 // token id
            )
        );
        vm.prank(alice);
        v1.transfer(bob, 1, 100);
    }

    function test_transferBalanceRecords_multipleTransfers() public {
        // Set TTL
        vm.prank(owner);
        v1.setTTL(1, 100);

        // Mint to Alice
        vm.prank(owner);
        v1.mint(alice, 1, 100);
        uint256 expiry = v1.expiresAt(1);

        // Alice transfers to Bob
        vm.prank(alice);
        v1.transfer(bob, 1, 40);

        // Bob transfers to Carol
        vm.prank(bob);
        v1.transfer(carol, 1, 20);

        // Alice transfers more to Carol
        vm.prank(alice);
        v1.transfer(carol, 1, 30);

        // Check final balances
        assertEq(v1.balanceOf(alice, 1), 30);
        assertEq(v1.balanceOf(bob, 1), 20);
        assertEq(v1.balanceOf(carol, 1), 50);

        // All should have same expiration
        TokenEphemeral.BalanceRecord[] memory carolRecords = v1.balanceRecordsOf(carol, 1);
        assertEq(carolRecords.length, 1);
        assertEq(carolRecords[0].expiresAt, expiry);
    }

    function test_pruneBalanceRecords_shrinksArray() public {
        // Set TTL for creating buckets
        uint256 maxRecords = v1.maxBalanceRecords();
        vm.prank(owner);
        v1.setTTL(1, uint48(maxRecords)); // 1-second time buckets

        // Create multiple balance records
        vm.startPrank(owner);
        for (uint256 i = 0; i < maxRecords; i++) {
            v1.mint(alice, 1, 2);
            vm.warp(block.timestamp + 1); // Advance time to create new buckets
        }
        vm.stopPrank();

        // Let half of the records expire
        vm.warp(block.timestamp + maxRecords / 2);

        // Prune expired records
        v1.pruneBalanceRecords(alice, 1);

        // Check records are compacted
        TokenEphemeral.BalanceRecord[] memory records = v1.balanceRecordsOf(alice, 1);
        assertLe(records.length, maxRecords / 2);

        // Let the rest expire
        vm.warp(block.timestamp + maxRecords);
        v1.pruneBalanceRecords(alice, 1);

        // Array size should be zero
        records = v1.balanceRecordsOf(alice, 1);
        assertEq(records.length, 0);
    }
}
