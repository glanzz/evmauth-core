// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { TokenAccessControl } from "src/base/TokenAccessControl.sol";
import { BaseTestWithAccessControl } from "test/_helpers/BaseTest.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAccessControlDefaultAdminRules } from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenAccessControlV1 is TokenAccessControl, UUPSUpgradeable {
    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     */
    function initialize(uint48 initialDelay, address initialDefaultAdmin) public initializer {
        __MockTokenAccessControlV1_init(initialDelay, initialDefaultAdmin);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     */
    function __MockTokenAccessControlV1_init(uint48 initialDelay, address initialDefaultAdmin)
        internal
        onlyInitializing
    {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
        __MockTokenAccessControlV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockTokenAccessControlV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller is not authorized.
    }
}

contract TokenAccessControlTest is BaseTestWithAccessControl {
    MockTokenAccessControlV1 internal v1;

    // ============ Test Setup ============= //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenAccessControlV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "TokenAccessControl.t.sol:MockTokenAccessControlV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenAccessControlV1.initialize, (2 days, owner));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockTokenAccessControlV1(proxyAddress);
    }

    function _grantRoles() internal override {
        v1.grantRole(UPGRADE_MANAGER_ROLE, owner);
        v1.grantRole(ACCESS_MANAGER_ROLE, accessManager);
        v1.grantRole(TOKEN_MANAGER_ROLE, tokenManager);
        v1.grantRole(MINTER_ROLE, minter);
        v1.grantRole(BURNER_ROLE, burner);
        v1.grantRole(TREASURER_ROLE, treasurer);
    }

    // ============ Initialization Tests ============= //

    function test_initialize() public view {
        assertTrue(v1.hasRole(DEFAULT_ADMIN_ROLE, owner));
    }

    // ============ Role Tests ============= //

    function test_roles() public view {
        assertEq(v1.DEFAULT_ADMIN_ROLE(), DEFAULT_ADMIN_ROLE);
        assertEq(v1.UPGRADE_MANAGER_ROLE(), UPGRADE_MANAGER_ROLE);
        assertEq(v1.ACCESS_MANAGER_ROLE(), ACCESS_MANAGER_ROLE);
        assertEq(v1.TOKEN_MANAGER_ROLE(), TOKEN_MANAGER_ROLE);
        assertEq(v1.MINTER_ROLE(), MINTER_ROLE);
        assertEq(v1.BURNER_ROLE(), BURNER_ROLE);
        assertEq(v1.TREASURER_ROLE(), TREASURER_ROLE);
    }

    function test_hasRole() public view {
        assertTrue(v1.hasRole(UPGRADE_MANAGER_ROLE, owner));
        assertTrue(v1.hasRole(ACCESS_MANAGER_ROLE, accessManager));
        assertTrue(v1.hasRole(TOKEN_MANAGER_ROLE, tokenManager));
        assertTrue(v1.hasRole(MINTER_ROLE, minter));
        assertTrue(v1.hasRole(BURNER_ROLE, burner));
        assertTrue(v1.hasRole(TREASURER_ROLE, treasurer));
    }

    // ============ Account Freezing Tests ============= //

    function test_freezeAccount() public {
        // Verify that accessManager has the ACCESS_MANAGER_ROLE
        assertTrue(v1.hasRole(ACCESS_MANAGER_ROLE, accessManager));

        // Freeze Alice's account
        vm.prank(accessManager);
        v1.freezeAccount(alice);

        // Verify that Alice's account is frozen
        assertTrue(v1.isFrozen(alice));
    }

    function testRevert_freezeAccount_AccessControlUnauthorizedAccount() public {
        // Verify that Alice does not have the ACCESS_MANAGER_ROLE
        assertFalse(v1.hasRole(ACCESS_MANAGER_ROLE, alice));

        // Expect a revert when Alice tries to freeze an account
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        v1.freezeAccount(bob);
        vm.stopPrank();
    }

    function test_unfreezeAccount() public {
        // Verify that accessManager has the ACCESS_MANAGER_ROLE
        assertTrue(v1.hasRole(ACCESS_MANAGER_ROLE, accessManager));

        // Freeze Alice's account first
        vm.prank(accessManager);
        v1.freezeAccount(alice);
        assertTrue(v1.isFrozen(alice));

        // Now unfreeze Alice's account
        vm.prank(accessManager);
        v1.unfreezeAccount(alice);

        // Verify that Alice's account is no longer frozen
        assertFalse(v1.isFrozen(alice));
    }

    function testRevert_unfreezeAccount_AccessControlUnauthorizedAccount() public {
        // Verify that Alice does not have the ACCESS_MANAGER_ROLE
        assertFalse(v1.hasRole(ACCESS_MANAGER_ROLE, alice));

        // Expect a revert when Alice tries to unfreeze an account
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        v1.unfreezeAccount(bob);
        vm.stopPrank();
    }

    // ============ Pausable Tests ============= //

    function test_pause() public {
        // Verify that accessManager has the ACCESS_MANAGER_ROLE
        assertTrue(v1.hasRole(ACCESS_MANAGER_ROLE, accessManager));

        // Pause the contract
        vm.prank(accessManager);
        v1.pause();

        // Verify that the contract is paused
        assertTrue(v1.paused());
    }

    function testRevert_pause_AccessControlUnauthorizedAccount() public {
        // Verify that Alice does not have the ACCESS_MANAGER_ROLE
        assertFalse(v1.hasRole(ACCESS_MANAGER_ROLE, alice));

        // Expect a revert when Alice tries to pause the contract
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        v1.pause();
        vm.stopPrank();
    }

    function test_unpause() public {
        // Verify that accessManager has the ACCESS_MANAGER_ROLE
        assertTrue(v1.hasRole(ACCESS_MANAGER_ROLE, accessManager));

        // Pause the contract first
        vm.prank(accessManager);
        v1.pause();
        assertTrue(v1.paused());

        // Now unpause the contract
        vm.prank(accessManager);
        v1.unpause();

        // Verify that the contract is no longer paused
        assertFalse(v1.paused());
    }

    function testRevert_unpause_AccessControlUnauthorizedAccount() public {
        // Verify that Alice does not have the ACCESS_MANAGER_ROLE
        assertFalse(v1.hasRole(ACCESS_MANAGER_ROLE, alice));

        // Expect a revert when Alice tries to unpause the contract
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, ACCESS_MANAGER_ROLE)
        );
        v1.unpause();
        vm.stopPrank();
    }

    // ============ Default Admin Tests ============= //

    function test_beginDefaultAdminTransfer() public {
        // Verify that owner has the DEFAULT_ADMIN_ROLE
        assertTrue(v1.hasRole(DEFAULT_ADMIN_ROLE, owner));

        // Begin transfer of default admin role to Alice
        vm.prank(owner);
        v1.beginDefaultAdminTransfer(alice);

        // Get transfer delay
        uint48 delay = v1.defaultAdminDelay();

        // Verify that Alice is the pending default admin
        (address pendingAdmin, uint48 schedule) = v1.pendingDefaultAdmin();
        assertEq(pendingAdmin, alice);
        assertEq(schedule, uint48(block.timestamp + delay));

        // Verify that the transfer cannot be completed immediately
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );
        vm.prank(alice);
        v1.acceptDefaultAdminTransfer();

        // Fast forward time
        vm.warp(block.timestamp + delay + 1);

        // Now accept the transfer
        vm.prank(alice);
        v1.acceptDefaultAdminTransfer();

        // Verify that Alice is now the default admin
        assertTrue(v1.hasRole(DEFAULT_ADMIN_ROLE, alice));
        assertFalse(v1.hasRole(DEFAULT_ADMIN_ROLE, owner));
    }

    function test_changeDefaultAdminDelay() public {
        // Verify that owner has the DEFAULT_ADMIN_ROLE
        assertTrue(v1.hasRole(DEFAULT_ADMIN_ROLE, owner));

        // Begin change of default admin delay
        uint48 oldDelay = v1.defaultAdminDelay(); // 172800
        vm.prank(owner);
        v1.changeDefaultAdminDelay(oldDelay + 1 days);

        // Verify that the delay change is pending
        (uint48 pendingDelay, uint48 schedule) = v1.pendingDefaultAdminDelay();
        assertEq(pendingDelay, oldDelay + 1 days);

        // Expected delay change schedule depends on whether the delay was increased or decreased
        uint48 expectedSchedule;
        if (pendingDelay > oldDelay) {
            expectedSchedule = uint48(block.timestamp + pendingDelay);
        } else {
            expectedSchedule = uint48(block.timestamp + oldDelay - pendingDelay);
        }
        assertEq(schedule, expectedSchedule);

        // Fast forward time
        vm.warp(expectedSchedule + 1);

        // Now the delay change should be in effect
        uint48 newDelay = v1.defaultAdminDelay();
        assertEq(newDelay, pendingDelay);
    }
}
