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

    function _getContractName() internal pure override returns (string memory) {
        return "TokenEphemeral.t.sol:MockTokenEphemeralV1";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenEphemeralV1.initialize, (owner));
    }

    function _setToken(address proxyAddress) internal override {
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
}
