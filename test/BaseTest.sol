// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Base contract mixin to include common users for testing.
 */
abstract contract WithUsers is Test {
    address public owner;
    address internal unauthorizedAccount;

    address public alice;
    address public bob;
    address public carol;

    function _setUpUsers() internal {
        owner = makeAddr("owner");
        unauthorizedAccount = makeAddr("unauthorizedAccount");

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
    }
}

/**
 * @dev Base contract mixin to include users for {TokenAccessControl} roles.
 */
abstract contract WithAccessControl is Test {
    address public accessManager;
    address public tokenManager;
    address public minter;
    address public burner;
    address public treasurer;

    function _setUpAccessControl() internal {
        accessManager = makeAddr("accessManager");
        tokenManager = makeAddr("tokenManager");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        treasurer = makeAddr("treasurer");
    }

    /**
     * @dev Grant roles to the respective users.
     * Must be overridden by inheriting contracts to specify role assignments.
     */
    function _grantRoles() internal virtual;
}

/**
 * @dev Base contract mixin to include a treasury address for {TokenPrice}.
 */
abstract contract WithTreasury is Test {
    address payable public treasury;

    function _setUpTreasury() internal {
        treasury = payable(makeAddr("treasury"));
    }
}

/**
 * @dev Base contract mixin to include mock ERC20 tokens for testing.
 */
abstract contract WithERC20s is Test {
    ERC20Mock internal usdc;
    ERC20Mock internal usdt;

    function _setUpERC20s() public virtual {
        usdc = new ERC20Mock();
        usdt = new ERC20Mock();
    }
}

/**
 * @dev Base contract mixin to include upgradeable contract deployment and testing.
 * Inheriting contracts must implement the abstract methods to specify the contract name,
 * initializer data, and token type.
 */
abstract contract WithUpgrades is WithUsers {
    address internal proxy;

    /**
     * @dev Deploy the upgradeable contract proxy and initialize it.
     * Should be called in the `setUp` function of inheriting contracts.
     */
    function _deployContract() public virtual {
        vm.prank(owner);
        proxy = Upgrades.deployUUPSProxy(_getContractName(), _getInitializerData());
        _setToken(proxy);
    }

    // ========== Abstract Methods To Be Implemented ==========

    /**
     * @dev Deploy and return a new implementation contract for upgrade testing.
     * Must be overridden by inheriting contracts to return the specific implementation.
     */
    function _deployNewImplementation() internal virtual returns (address);

    /**
     * @dev Get the contract name for deployment.
     * Must be overridden by inheriting contracts.
     */
    function _getContractName() internal view virtual returns (string memory);

    /**
     * @dev Get the initialization call data.
     * Must be overridden by inheriting contracts.
     */
    function _getInitializerData() internal view virtual returns (bytes memory);

    /**
     * @dev Set the token variable with the correct type.
     * Must be overridden by inheriting contracts to cast proxy to the specific token type.
     */
    function _setToken(address proxyAddress) internal virtual;

    // ========== Initialization and Upgrade Tests ==========

    /**
     * @dev Test that initialization succeeds with valid parameters.
     */
    function test_initialize() public virtual {
        // Deploy a new uninitialized implementation
        address implementation = _deployNewImplementation();

        // Get initialization data
        bytes memory initData = _getInitializerData();

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
        bytes memory initData = _getInitializerData();

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
        address newImplementation = _deployNewImplementation();

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
        address newImplementation = _deployNewImplementation();

        // Try to upgrade as unauthorized user
        vm.startPrank(unauthorizedAccount);
        bool success;
        vm.expectRevert();
        (success,) = proxy.call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, ""));
        vm.stopPrank();
    }
}

/**
 * @dev Base test harness for upgradeable contracts.
 */
abstract contract BaseTest is WithUpgrades {
    function setUp() public virtual {
        _setUpUsers();
        _deployContract();
    }
}

/**
 * @dev Base test harness for upgradeable contracts that inherit {TokenAccessControl}.
 */
abstract contract BaseTestWithAccessControl is WithUpgrades, WithAccessControl {
    function setUp() public virtual {
        _setUpUsers();
        _setUpAccessControl();
        _deployContract();
        _grantRoles();
    }
}

/**
 * @dev Base test harness for upgradeable contracts that inherit {TokenPrice}.
 */
abstract contract BaseTestWithTreasury is WithUpgrades, WithTreasury {
    function setUp() public virtual {
        _setUpUsers();
        _setUpTreasury();
        _deployContract();
    }
}

/**
 * @dev Base test harness for upgradeable contracts that inherit both {TokenAccessControl} and {TokenPrice}.
 */
abstract contract BaseTestWithAccessControlAndTreasury is WithUpgrades, WithAccessControl, WithTreasury {
    function setUp() public virtual {
        _setUpUsers();
        _setUpAccessControl();
        _setUpTreasury();
        _deployContract();
        _grantRoles();
    }
}

/**
 * @dev Base test harness for upgradeable contracts that interact with ERC20 tokens.
 */
abstract contract BaseTestWithERC20s is WithUpgrades, WithTreasury, WithERC20s {
    function setUp() public virtual {
        _setUpUsers();
        _setUpTreasury();
        _setUpERC20s();
        _deployContract();
    }
}

/**
 * @dev Base test harness for upgradeable contracts that inherit {TokenAccessControl} and interact with ERC20 tokens.
 */
abstract contract BaseTestWithAccessControlAndERC20s is WithUpgrades, WithAccessControl, WithTreasury, WithERC20s {
    function setUp() public virtual {
        _setUpUsers();
        _setUpAccessControl();
        _setUpTreasury();
        _setUpERC20s();
        _deployContract();
        _grantRoles();
    }
}
