// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { AccountFreezable } from "src/base/AccountFreezable.sol";
import { BaseTest } from "test/_helpers/BaseTest.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract MockAccountFreezableV1 is AccountFreezable, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function initialize(address initialOwner) public initializer {
        __MockAccountFreezableV1_init(initialOwner);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     * @param initialOwner The address to be set as the owner of the contract.
     */
    function __MockAccountFreezableV1_init(address initialOwner) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __AccountFreezable_init();
        __MockAccountFreezableV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockAccountFreezableV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not authorized.
    }

    /// @dev Expose internal function for testing
    function freezeAccount(address account) external onlyOwner {
        _freezeAccount(account);
    }

    /// @dev Expose internal function for testing
    function unfreezeAccount(address account) external onlyOwner {
        _unfreezeAccount(account);
    }

    /// @dev Expose modifier for testing
    function withModifierNotFrozen(address account) external view notFrozen(account) returns (bool) {
        return true;
    }
}

contract AccountFreezableTest is BaseTest {
    bytes32 public constant ACCOUNT_FROZEN_STATUS = keccak256("ACCOUNT_FROZEN_STATUS");
    bytes32 public constant ACCOUNT_UNFROZEN_STATUS = keccak256("ACCOUNT_UNFROZEN_STATUS");

    MockAccountFreezableV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockAccountFreezableV1());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "AccountFreezable.t.sol:MockAccountFreezableV1";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockAccountFreezableV1.initialize, (owner));
    }

    function _setToken(address proxyAddress) internal override {
        v1 = MockAccountFreezableV1(proxyAddress);
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertEq(v1.isFrozen(owner), false);

        // Check that the storage slot for AccountFreezable is correctly calculated to avoid storage collisions.
        assertEq(
            0xa095fe5a3c31691ae0832631cef3701285d36b2af1972f4c23463476b0353a00,
            keccak256(abi.encode(uint256(keccak256("accountfreezable.storage.AccountFreezable")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }

    function test_constants() public view {
        assertEq(v1.ACCOUNT_FROZEN_STATUS(), ACCOUNT_FROZEN_STATUS);
        assertEq(v1.ACCOUNT_UNFROZEN_STATUS(), ACCOUNT_UNFROZEN_STATUS);
    }

    function test_modifier_notFrozen_succeeds() public view {
        // Initially, Alice's account is not frozen
        assertEq(v1.isFrozen(alice), false);

        // Should not revert if the account is not frozen
        assertTrue(v1.withModifierNotFrozen(alice));
    }

    function testRevert_modifier_notFrozen_AccountFrozen() public {
        // Initially, Alice's account is not frozen
        assertEq(v1.isFrozen(alice), false);
        assertTrue(v1.withModifierNotFrozen(alice));

        // Freeze Alice's account
        vm.prank(owner);
        v1.freezeAccount(alice);
        assertEq(v1.isFrozen(alice), true);

        // Attempting to call the function with the modifier should revert
        vm.expectRevert(abi.encodeWithSelector(AccountFreezable.AccountFrozen.selector, alice));
        v1.withModifierNotFrozen(alice);

        // Unfreeze Alice's account
        vm.prank(owner);
        v1.unfreezeAccount(alice);
        assertEq(v1.isFrozen(alice), false);

        // Now the function should succeed again
        assertTrue(v1.withModifierNotFrozen(alice));
    }

    function test_isFrozen_succeeds() public {
        assertEq(v1.isFrozen(alice), false);

        vm.prank(owner);
        v1.freezeAccount(alice);
        assertEq(v1.isFrozen(alice), true);

        vm.prank(owner);
        v1.unfreezeAccount(alice);
        assertEq(v1.isFrozen(alice), false);
    }

    function test_frozenAccounts_succeeds() public {
        vm.startPrank(owner);
        v1.freezeAccount(alice);
        v1.freezeAccount(bob);
        vm.stopPrank();

        address[] memory frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 2);
        assertEq(frozenAccounts[0], alice);
        assertEq(frozenAccounts[1], bob);

        vm.prank(owner);
        v1.unfreezeAccount(alice);

        frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 1);
        assertEq(frozenAccounts[0], bob);
    }

    function test_freezeAccount_succeeds() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit AccountFreezable.AccountStatusUpdated(alice, ACCOUNT_FROZEN_STATUS);
        v1.freezeAccount(alice);
    }

    function test_freezeAccount_idempotent() public {
        // First freeze the account
        vm.prank(owner);
        v1.freezeAccount(alice);
        assertEq(v1.isFrozen(alice), true);

        // Freezing again should have no effect and should not revert
        vm.prank(owner);
        v1.freezeAccount(alice);
        assertEq(v1.isFrozen(alice), true);
    }

    function test_freezeAccount_eventNotEmitted() public {
        // First freeze the account
        vm.prank(owner);
        v1.freezeAccount(alice);

        // Now test that freezing again doesn't emit an event
        vm.recordLogs();
        vm.prank(owner);
        v1.freezeAccount(alice);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        // Check that no AccountStatusUpdated event was emitted
        for (uint256 i = 0; i < logs.length; i++) {
            assertFalse(
                logs[i].topics[0] == AccountFreezable.AccountStatusUpdated.selector,
                "AccountStatusUpdated should not be emitted when freezing already frozen account"
            );
        }
    }

    function testRevert_freezeAccount_InvalidAddress() public {
        // Expect a revert when trying to freeze the zero address
        vm.expectRevert(abi.encodeWithSelector(AccountFreezable.InvalidAddress.selector, address(0)));
        vm.prank(owner);
        v1.freezeAccount(address(0));
    }

    function test_unfreezeAccount_succeeds() public {
        // First freeze the account
        vm.prank(owner);
        v1.freezeAccount(alice);

        // Now unfreeze and check for event
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit AccountFreezable.AccountStatusUpdated(alice, ACCOUNT_UNFROZEN_STATUS);
        v1.unfreezeAccount(alice);
    }

    function test_unfreezeAccount_idempotent() public {
        // First freeze the account
        vm.prank(owner);
        v1.freezeAccount(bob);
        assertEq(v1.isFrozen(bob), true);

        // Now unfreeze
        vm.prank(owner);
        v1.unfreezeAccount(bob);
        assertEq(v1.isFrozen(bob), false);

        // Unfreezing again should have no effect and should not revert
        vm.prank(owner);
        v1.unfreezeAccount(bob);
        assertEq(v1.isFrozen(bob), false);
    }

    function test_unfreezeAccount_eventNotEmitted() public {
        // Ensure alice is not frozen
        assertEq(v1.isFrozen(alice), false);

        // Test that unfreezing a non-frozen account doesn't emit an event
        vm.recordLogs();
        vm.prank(owner);
        v1.unfreezeAccount(alice);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        // Check that no AccountStatusUpdated event was emitted
        for (uint256 i = 0; i < logs.length; i++) {
            assertFalse(
                logs[i].topics[0] == AccountFreezable.AccountStatusUpdated.selector,
                "AccountStatusUpdated should not be emitted when unfreezing non-frozen account"
            );
        }
    }

    function test_unfreezeAccount_arrayIntegrity() public {
        // Freeze multiple accounts
        vm.startPrank(owner);
        v1.freezeAccount(alice);
        v1.freezeAccount(bob);
        v1.freezeAccount(carol);
        vm.stopPrank();

        // Verify all accounts are frozen
        address[] memory frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 3);
        assertEq(frozenAccounts[0], alice);
        assertEq(frozenAccounts[1], bob);
        assertEq(frozenAccounts[2], carol);

        // Unfreeze the middle account (bob) and check array integrity
        vm.prank(owner);
        v1.unfreezeAccount(bob);

        // Check that alice and carol are still frozen
        frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 2);
        assertEq(frozenAccounts[0], alice);
        assertEq(frozenAccounts[1], carol);

        // Unfreeze the first account (alice) and check array integrity
        vm.prank(owner);
        v1.unfreezeAccount(alice);

        // Check that only carol remains frozen
        frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 1);
        assertEq(frozenAccounts[0], carol);

        // Unfreeze the last account (carol) and check array integrity
        vm.prank(owner);
        v1.unfreezeAccount(carol);

        // Check that no accounts are frozen
        frozenAccounts = v1.frozenAccounts();
        assertEq(frozenAccounts.length, 0);
    }
}
