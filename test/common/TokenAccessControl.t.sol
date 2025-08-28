// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BaseTest } from "test/BaseTest.sol";
import { BaseUpgradeTest } from "test/BaseUpgradeTest.sol";
import { TokenAccessControl } from "src/common/TokenAccessControl.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IAccessControlDefaultAdminRules } from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract MockTokenAccessControl is TokenAccessControl, UUPSUpgradeable {
    function initialize(uint48 initialDelay, address initialDefaultAdmin) public initializer {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
    }

    function restrictedForFrozenCaller() public view notFrozen(_msgSender()) {
        // This function will revert if the caller is frozen
    }

    function restrictedForFrozenAccount(address account) public view notFrozen(account) {
        // This function will revert if the `account` is frozen
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller does not have the UPGRADE_MANAGER_ROLE
    }
}

abstract contract BaseTokenAccessControlTest is BaseTest {
    MockTokenAccessControl internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "TokenAccessControl.t.sol:MockTokenAccessControl",
            abi.encodeCall(MockTokenAccessControl.initialize, (2 days, owner))
        );
        token = MockTokenAccessControl(proxy);

        // Grant roles
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        vm.stopPrank();
    }
}

contract TokenAccessControl_UnitTest is BaseTokenAccessControlTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testRevert_freezeAccount_ZeroAddress() public {
        // Try to freeze address(0)
        vm.prank(accessManager);
        vm.expectRevert(abi.encodeWithSelector(TokenAccessControl.InvalidAddress.selector, address(0)));
        token.freezeAccount(address(0));
    }

    function test_supportsInterface() public view {
        assertTrue(token.supportsInterface(type(IAccessControlDefaultAdminRules).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));

        // Test an unsupported interface
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_roleConstants() public view {
        assertEq(token.DEFAULT_ADMIN_ROLE(), 0x00);
        assertEq(token.UPGRADE_MANAGER_ROLE(), keccak256("UPGRADE_MANAGER_ROLE"));
        assertEq(token.ACCESS_MANAGER_ROLE(), keccak256("ACCESS_MANAGER_ROLE"));
        assertEq(token.TOKEN_MANAGER_ROLE(), keccak256("TOKEN_MANAGER_ROLE"));
        assertEq(token.MINTER_ROLE(), keccak256("MINTER_ROLE"));
        assertEq(token.BURNER_ROLE(), keccak256("BURNER_ROLE"));
        assertEq(token.TREASURER_ROLE(), keccak256("TREASURER_ROLE"));
    }

    function test_frozenStatusConstants() public view {
        assertEq(token.ACCOUNT_FROZEN_STATUS(), keccak256("ACCOUNT_FROZEN_STATUS"));
        assertEq(token.ACCOUNT_UNFROZEN_STATUS(), keccak256("ACCOUNT_UNFROZEN_STATUS"));
    }

    function test_freezeAccount() public {
        // Initially, `alice` should not be frozen
        assertFalse(token.isFrozen(alice));

        // Freeze `alice`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Verify that `alice` is frozen
        assertTrue(token.isFrozen(alice));
    }

    function test_freezeAccount_idempotent() public {
        // Initially, `alice` should not be frozen
        assertFalse(token.isFrozen(alice));

        // Freeze `alice`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Verify that `alice` is frozen
        assertTrue(token.isFrozen(alice));

        // Freeze `alice` again (should be idempotent)
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Verify that `alice` is still frozen
        assertTrue(token.isFrozen(alice));
    }

    function test_freezeAccount_emitsEvent() public {
        // Expect the AccountStatusUpdated event to be emitted
        vm.expectEmit(true, false, false, true);
        emit TokenAccessControl.AccountStatusUpdated(alice, token.ACCOUNT_FROZEN_STATUS());

        // Freeze `alice`
        vm.prank(accessManager);
        token.freezeAccount(alice);
    }

    function testRevert_freezeAccount_Unauthorized() public {
        // Confirm `bob` does not have the `ACCESS_MANAGER_ROLE`
        assertFalse(token.hasRole(token.ACCESS_MANAGER_ROLE(), bob));

        // Try to freeze `alice` as `bob`, without the necessary role
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, bob, token.ACCESS_MANAGER_ROLE()
            )
        );
        token.freezeAccount(alice);
        vm.stopPrank();
    }

    function test_unfreezeAccount() public {
        // Freeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Confirm that `alice` is frozen
        assertTrue(token.isFrozen(alice));

        // Unfreeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        // Confirm that `alice` is no longer frozen
        assertFalse(token.isFrozen(alice));
    }

    function test_unfreezeAccount_idempotent() public {
        // Freeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Confirm that `alice` is frozen
        assertTrue(token.isFrozen(alice));

        // Unfreeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        // Confirm that `alice` is no longer frozen
        assertFalse(token.isFrozen(alice));

        // Unfreeze `alice` again (should be idempotent)
        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        // Confirm that `alice` is still not frozen
        assertFalse(token.isFrozen(alice));
    }

    function test_unfreezeAccount_emitsEvent() public {
        // Freeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Expect the AccountStatusUpdated event to be emitted
        vm.expectEmit(true, false, false, true);
        emit TokenAccessControl.AccountStatusUpdated(alice, token.ACCOUNT_UNFROZEN_STATUS());

        // Unfreeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.unfreezeAccount(alice);
    }

    function testRevert_unfreezeAccount_Unauthorized() public {
        // Freeze `alice` as `accessManager`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Confirm `bob` does not have the `ACCESS_MANAGER_ROLE`
        assertFalse(token.hasRole(token.ACCESS_MANAGER_ROLE(), bob));

        // Try to unfreeze `alice` as `bob`, without the necessary role
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, bob, token.ACCESS_MANAGER_ROLE()
            )
        );
        token.unfreezeAccount(alice);
        vm.stopPrank();
    }

    function test_modifier_notFrozen() public {
        // Ensure `alice` is not frozen
        assertFalse(token.isFrozen(alice));

        // Call the restricted function as `alice`
        vm.prank(alice);
        token.restrictedForFrozenCaller();

        // Call the restricted function with `alice` as the parameter
        token.restrictedForFrozenAccount(alice);
    }

    function testRevert_modifier_notFrozen_FrozenCaller() public {
        // Freeze `alice`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to call the restricted function as `alice`, which is frozen
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TokenAccessControl.AccountFrozen.selector, alice));
        token.restrictedForFrozenCaller();
    }

    function testRevert_modifier_notFrozen_FrozenAccount() public {
        // Freeze `alice`
        vm.prank(accessManager);
        token.freezeAccount(alice);

        // Try to call the restricted function with `alice` as the parameter, which is frozen
        vm.expectRevert(abi.encodeWithSelector(TokenAccessControl.AccountFrozen.selector, alice));
        token.restrictedForFrozenAccount(alice);
    }

    function test_frozenAccounts() public {
        // Initially, there should be no frozen accounts
        address[] memory frozenAccounts = token.frozenAccounts();
        assertEq(frozenAccounts.length, 0);

        // Freeze `alice` and `bob`
        vm.startPrank(accessManager);
        token.freezeAccount(alice);
        token.freezeAccount(bob);
        vm.stopPrank();

        // Verify that `alice` and `bob` are in the frozen accounts list
        frozenAccounts = token.frozenAccounts();
        assertEq(frozenAccounts.length, 2);
        assertEq(frozenAccounts[0], alice);
        assertEq(frozenAccounts[1], bob);

        // Unfreeze `alice`
        vm.prank(accessManager);
        token.unfreezeAccount(alice);

        // Verify that only `bob` remains in the frozen accounts list
        frozenAccounts = token.frozenAccounts();
        assertEq(frozenAccounts.length, 1);
        assertEq(frozenAccounts[0], bob);
    }
}

contract TokenAccessControl_UpgradeTest is BaseUpgradeTest {
    MockTokenAccessControl internal token;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(owner);
        token.grantRole(token.UPGRADE_MANAGER_ROLE(), owner);
        vm.stopPrank();
    }

    function setToken(address proxyAddress) internal override {
        token = MockTokenAccessControl(proxyAddress);
    }

    function deployNewImplementation() internal override returns (address) {
        return address(new MockTokenAccessControl());
    }

    function getContractName() internal pure override returns (string memory) {
        return "TokenAccessControl.t.sol:MockTokenAccessControl";
    }

    function getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenAccessControl.initialize, (2 days, owner));
    }
}
