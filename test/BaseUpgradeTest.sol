// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Base contract for testing upgradeable contracts.
 * Provides common test patterns for initialization and upgrade authorization.
 * Does not inherit from BaseTest to keep it independent.
 */
abstract contract BaseUpgradeTest is Test {
    address internal proxy;
    address internal owner;
    address internal unauthorizedAccount;

    function setUp() public virtual {
        owner = makeAddr("owner");
        unauthorizedAccount = makeAddr("unauthorizedAccount");

        // Deploy the proxy and initialize
        vm.prank(owner);
        proxy = Upgrades.deployUUPSProxy(getContractName(), getInitializerData());

        // Set the token with the correct type
        setToken(proxy);
    }

    /**
     * @dev Set the token variable with the correct type.
     * Must be overridden by inheriting contracts to cast proxy to the specific token type.
     */
    function setToken(address proxyAddress) internal virtual;

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
     * @dev Test that initialization succeeds with valid parameters.
     */
    function test_initialize() public virtual {
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
     * @dev Test that initializer reverts when called after initialization.
     */
    function testRevert_initialize_InvalidInitialization() public virtual {
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
    function test_authorizeUpgrade() public virtual {
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
    function testRevert_authorizeUpgrade_Unauthorized() public virtual {
        // Deploy new implementation
        address newImplementation = deployNewImplementation();

        // Try to upgrade as unauthorized user
        vm.startPrank(unauthorizedAccount);
        bool success;
        vm.expectRevert();
        (success,) = proxy.call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, ""));
        vm.stopPrank();
    }
}
