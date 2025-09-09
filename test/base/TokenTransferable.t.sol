// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenTransferable } from "src/base/TokenTransferable.sol";
import { BaseTest } from "test/_helpers/BaseTest.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenTransferableV1 is TokenTransferable, OwnableUpgradeable, UUPSUpgradeable {
    // For testing only; in a real implementation, use a token standard like ERC-1155 or ERC-6909.
    mapping(address => mapping(uint256 => uint256)) public balances;

    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function initialize(address initialOwner) public initializer {
        __MockTokenTransferableV1_init(initialOwner);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function __MockTokenTransferableV1_init(address initialOwner) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __TokenTransferable_init();
        __MockTokenTransferableV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockTokenTransferableV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not authorized.
    }

    /// @dev Expose internal function for testing
    function setTransferable(uint256 tokenId, bool transferable) external onlyOwner {
        _setTransferable(tokenId, transferable);
    }

    /// @dev Expose modifier for testing
    function withModifierTokenTransferable(address from, address to, uint256 id)
        external
        view
        tokenTransferable(from, to, id)
        returns (bool)
    {
        return true;
    }

    /// @dev Expose modifier for testing
    function withModifierAllTokensTransferable(address from, address to, uint256[] memory ids)
        external
        view
        allTokensTransferable(from, to, ids)
        returns (bool)
    {
        return true;
    }
}

contract TokenTransferableTest is BaseTest {
    MockTokenTransferableV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenTransferableV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "TokenTransferable.t.sol:MockTokenTransferableV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenTransferableV1.initialize, (owner));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockTokenTransferableV1(proxyAddress);
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertEq(v1.isTransferable(1), false);

        // Check that the storage slot for TokenTransferable is correctly calculated to avoid storage collisions.
        assertEq(
            0xdaa3d1cf82c71b982a9e24ff7dadd71a10e8c3e82a219c0e60ca5c6b8e617700,
            keccak256(abi.encode(uint256(keccak256("tokentransferable.storage.TokenTransferable")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }

    function test_setTransferable() public {
        // Verify default is true
        assertEq(v1.isTransferable(1), false, "Default should be false");

        // Set back to true and verify
        vm.prank(owner);
        v1.setTransferable(1, true);
        assertEq(v1.isTransferable(1), true, "Should be true after setting to true");

        // Set to false and verify
        vm.prank(owner);
        v1.setTransferable(1, false);
        assertEq(v1.isTransferable(1), false, "Should be false after setting to false");
    }

    function test_modifier_tokenTransferable_succeeds() public {
        // Set token ID 1 to transferable
        vm.prank(owner);
        v1.setTransferable(1, true);

        // Should succeed for transfers
        assertTrue(v1.withModifierTokenTransferable(alice, bob, 1));
        assertTrue(v1.withModifierTokenTransferable(address(0), carol, 1)); // mint
        assertTrue(v1.withModifierTokenTransferable(bob, address(0), 1)); // burn

        // Set token ID 2 to non-transferable
        vm.prank(owner);
        v1.setTransferable(2, false);

        // Should succeed for minting and burning
        assertTrue(v1.withModifierTokenTransferable(address(0), alice, 2)); // mint
        assertTrue(v1.withModifierTokenTransferable(bob, address(0), 2)); // burn
    }

    function testRevert_modifier_tokenTransferable_TokenIsNonTransferable() public {
        // Set token ID 1 to non-transferable
        vm.prank(owner);
        v1.setTransferable(1, false);

        // Should revert for transfers
        vm.expectRevert(abi.encodeWithSelector(TokenTransferable.TokenIsNonTransferable.selector, 1));
        v1.withModifierTokenTransferable(alice, bob, 1);
    }

    function test_modifier_allTokensTransferable_succeeds() public {
        // Set token IDs 1 and 2 to transferable
        vm.prank(owner);
        v1.setTransferable(1, true);
        vm.prank(owner);
        v1.setTransferable(2, true);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        // Should succeed for transfers
        assertTrue(v1.withModifierAllTokensTransferable(alice, bob, ids));
        assertTrue(v1.withModifierAllTokensTransferable(address(0), carol, ids)); // mint
        assertTrue(v1.withModifierAllTokensTransferable(bob, address(0), ids)); // burn

        // Set token ID 3 to non-transferable
        vm.prank(owner);
        v1.setTransferable(3, false);

        uint256[] memory idsWithNonTransferable = new uint256[](3);
        idsWithNonTransferable[0] = 1;
        idsWithNonTransferable[1] = 2;
        idsWithNonTransferable[2] = 3;

        // Should succeed for minting and burning
        assertTrue(v1.withModifierAllTokensTransferable(address(0), alice, idsWithNonTransferable)); // mint
        assertTrue(v1.withModifierAllTokensTransferable(bob, address(0), idsWithNonTransferable)); // burn
    }

    function testRevert_modifier_allTokensTransferable_TokenIsNonTransferable() public {
        // Set token ID 1 to transferable and ID 2 to non-transferable
        vm.prank(owner);
        v1.setTransferable(1, true);
        vm.prank(owner);
        v1.setTransferable(2, false);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        // Should revert for transfers
        vm.expectRevert(abi.encodeWithSelector(TokenTransferable.TokenIsNonTransferable.selector, 2));
        v1.withModifierAllTokensTransferable(alice, bob, ids);
    }
}
