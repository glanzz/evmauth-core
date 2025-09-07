// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenEnumerable } from "src/base/TokenEnumerable.sol";
import { BaseTest } from "test/_helpers/BaseTest.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenEnumerableV1 is TokenEnumerable, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function initialize(address initialOwner) public initializer {
        __MockTokenEnumerableV1_init(initialOwner);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function __MockTokenEnumerableV1_init(address initialOwner) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __TokenEnumerable_init();
        __MockTokenEnumerableV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockTokenEnumerableV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not authorized.
    }

    /// @dev Expose internal function for testing
    function claimNextTokenID() external returns (uint256) {
        return _claimNextTokenID();
    }

    /// @dev Expose modifier for testing
    function withModifierTokenExists(uint256 id) external view tokenExists(id) returns (bool) {
        return true;
    }

    /// @dev Expose modifier for testing
    function withModifierAllTokensExist(uint256[] calldata ids) external view allTokensExist(ids) returns (bool) {
        return true;
    }
}

contract TokenEnumerableTest is BaseTest {
    MockTokenEnumerableV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenEnumerableV1());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "TokenEnumerable.t.sol:MockTokenEnumerableV1";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenEnumerableV1.initialize, (owner));
    }

    function _setToken(address proxyAddress) internal override {
        v1 = MockTokenEnumerableV1(proxyAddress);
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertFalse(v1.exists(1));

        // Check that the storage slot for TokenEnumerable is correctly calculated to avoid storage collisions.
        assertEq(
            0x591f2d2df77efc80b9969dfd51dd4fc103fe490745902503f7c21df07a35d600,
            keccak256(abi.encode(uint256(keccak256("tokenenumerable.storage.TokenEnumerable")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }

    function test_nextTokenID_succeeds() public view {
        // Token IDs should start at 1
        assertEq(v1.nextTokenID(), 1);
    }

    function test_exists_succeeds() public {
        // Initially, no token IDs should exist
        assertFalse(v1.exists(0)); // ID 0 should not exist
        assertFalse(v1.exists(1)); // ID 1 should not exist
        assertFalse(v1.exists(100)); // ID 100 should not exist

        // Claim a token ID to test existence
        uint256 tokenID = v1.claimNextTokenID();
        assertEq(tokenID, 1);

        // Now, ID 1 should exist
        assertTrue(v1.exists(1));
        assertFalse(v1.exists(2)); // ID 2 should still not exist
    }

    function test_claimNextTokenID_succeeds() public {
        // Claim token IDs 1 through 3
        for (uint256 i = 1; i <= 3; i++) {
            // Before claiming, the token ID should not exist
            assertFalse(v1.exists(i));

            // Claim the next token ID
            uint256 tokenID = v1.claimNextTokenID();
            assertEq(tokenID, i);

            // After claiming, the token ID should exist
            assertTrue(v1.exists(tokenID));

            // Assert that the next token ID is i + 1
            uint256 nextTokenID = v1.nextTokenID();
            assertEq(nextTokenID, tokenID + 1);
        }
    }

    function test_modifier_tokenExists_succeeds() public {
        // Claim a token ID to test existence
        uint256 tokenID = v1.claimNextTokenID();
        assertEq(tokenID, 1);

        // Test with a valid token ID
        assertTrue(v1.withModifierTokenExists(1));
    }

    function testRevert_modifier_tokenExists_InvalidTokenID() public {
        // Test with token ID 0, which is always invalid
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 0));
        v1.withModifierTokenExists(0);

        // Verify token ID 1 does not exist yet
        assertFalse(v1.exists(1));

        // Test with token ID 1
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 1));
        v1.withModifierTokenExists(1);
    }

    function test_modifier_allTokensExist_succeeds() public {
        // Claim token IDs 1 through 3
        for (uint256 i = 1; i <= 3; i++) {
            uint256 tokenID = v1.claimNextTokenID();
            assertEq(tokenID, i);
        }

        // Test with valid token IDs
        uint256[] memory validIDs = new uint256[](3);
        validIDs[0] = 1;
        validIDs[1] = 2;
        validIDs[2] = 3;
        assertTrue(v1.withModifierAllTokensExist(validIDs));
    }

    function testRevert_modifier_allTokensExist_InvalidTokenID() public {
        // Claim token ID 1
        uint256 tokenID = v1.claimNextTokenID();
        assertEq(tokenID, 1);

        // Test with an array containing an invalid token ID (0)
        uint256[] memory idsWithZero = new uint256[](2);
        idsWithZero[0] = 0;
        idsWithZero[1] = 1;
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 0));
        v1.withModifierAllTokensExist(idsWithZero);

        // Test with an array containing a non-existent token ID (2)
        uint256[] memory idsWithTwo = new uint256[](2);
        idsWithTwo[0] = 1;
        idsWithTwo[1] = 2;
        vm.expectRevert(abi.encodeWithSelector(TokenEnumerable.InvalidTokenID.selector, 2));
        v1.withModifierAllTokensExist(idsWithTwo);
    }
}
