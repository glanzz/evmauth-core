// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @dev Base contract for testing upgradeable contracts.
 * Provides common test patterns for initialization and upgrade authorization.
 * Does not inherit from BaseTest to keep it independent.
 */
abstract contract BaseUpgradeTest is Test {
    address internal proxy;
    address internal owner;
    address internal unauthorizedAccount;
    address payable internal treasury;

    // Common role constants for contracts with AccessControl
    bytes32 internal constant UPGRADE_MANAGER_ROLE = keccak256("UPGRADE_MANAGER_ROLE");
    bytes32 internal constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 internal constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 internal constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    function setUp() public virtual {
        owner = makeAddr("owner");
        unauthorizedAccount = makeAddr("unauthorizedAccount");
        treasury = payable(makeAddr("treasury"));
    }

    /**
     * @dev Deploy and return a new implementation contract for upgrade testing.
     * Must be overridden by inheriting contracts to return the specific implementation.
     */
    function deployNewImplementation() internal virtual returns (address);

    /**
     * @dev Get the contract name for deployment.
     * Must be overridden by inheriting contracts.
     */
    function getContractName() internal view virtual returns (string memory);

    /**
     * @dev Get the initialization call data.
     * Must be overridden by inheriting contracts.
     */
    function getInitializerData() internal view virtual returns (bytes memory);

    /**
     * @dev Check if the contract has access control (role-based permissions).
     * Override to return true for contracts with AccessControl.
     */
    function hasAccessControl() internal pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Check if the contract has UUPS upgrade functionality.
     * Override to return false for non-upgradeable contracts.
     */
    function hasUpgradeability() internal pure virtual returns (bool) {
        return true;
    }

    /**
     * @dev Grant the UPGRADE_MANAGER_ROLE to the owner address.
     * Should be called in setUp for contracts with access control.
     */
    function grantUpgradeRole() internal virtual {
        if (hasAccessControl()) {
            vm.prank(owner);
            IAccessControl(proxy).grantRole(UPGRADE_MANAGER_ROLE, owner);
        }
    }

    /**
     * @dev Test that initialization succeeds with valid parameters.
     */
    function test_initialize_success() public virtual {
        // Deploy a new uninitialized implementation
        address implementation = deployNewImplementation();

        // Get initialization data
        bytes memory initData = getInitializerData();

        // Call initialize directly on the implementation
        (bool success,) = implementation.call(initData);
        assertTrue(success, "Initialization should succeed");

        // Verify the contract was initialized
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        (success,) = implementation.call(initData);
    }

    /**
     * @dev Test that initialization reverts when called twice.
     */
    function test_initialize_revertWhenCalledTwice() public virtual {
        // Try to call the initializer again on the already initialized proxy
        bytes memory initData = getInitializerData();

        // Expect revert due to already being initialized
        vm.startPrank(owner);
        bool success;
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        (success,) = proxy.call(initData);
        vm.stopPrank();
    }

    /**
     * @dev Test that authorized upgrade succeeds.
     * Only applicable for contracts with UUPS upgradeability.
     */
    function test_authorizeUpgrade_success() public virtual {
        vm.skip(!hasUpgradeability());

        // Deploy new implementation
        address newImplementation = deployNewImplementation();

        // Perform upgrade as owner (who has authorization)
        vm.prank(owner);

        // Verify upgrade succeeds
        (bool success,) = proxy.call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, ""));
        assertTrue(success, "Upgrade should succeed with proper authorization");
    }

    /**
     * @dev Test that unauthorized upgrade reverts.
     * Only applicable for contracts with UUPS upgradeability and access control.
     */
    function test_authorizeUpgrade_revertIfNotAuthorized() public virtual {
        vm.skip(!hasUpgradeability() || !hasAccessControl());

        // Deploy new implementation
        address newImplementation = deployNewImplementation();

        // Try to upgrade as unauthorized user
        vm.startPrank(unauthorizedAccount);
        bool success;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorizedAccount, UPGRADE_MANAGER_ROLE
            )
        );
        (success,) = proxy.call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, ""));
        vm.stopPrank();
    }
}
