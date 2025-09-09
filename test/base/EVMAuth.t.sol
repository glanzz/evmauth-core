// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { BaseTestWithAccessControlAndERC20s } from "test/_helpers/BaseTest.sol";

contract MockEVMAuthV1 is EVMAuth {
    // For testing only; in a real implementation, use a token standard like ERC-1155 or ERC-6909.
    mapping(address => mapping(uint256 => uint256)) public balances;

    /**
     * @dev Initializer used when deployed directly as an upgradeable contract.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param roleGrants The initial set of role grants to be applied.
     */
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        RoleGrant[] calldata roleGrants
    ) public initializer {
        __MockEVMAuthV1_init(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants);
    }

    /**
     * @dev Initializer that calls the parent initializers for upgradeable contracts.
     *
     * @param initialDelay The delay in seconds before a new default admin can exercise their role.
     * @param initialDefaultAdmin The address to be granted the initial default admin role.
     * @param initialTreasury The address where purchase revenues will be sent.
     * @param roleGrants The initial set of role grants to be applied.
     */
    function __MockEVMAuthV1_init(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address payable initialTreasury,
        RoleGrant[] calldata roleGrants
    ) internal onlyInitializing {
        __EVMAuth_init(initialDelay, initialDefaultAdmin, initialTreasury, roleGrants);
        __MockEVMAuthV1_init_unchained();
    }

    /**
     * @dev Unchained initializer that only initializes THIS contract's storage.
     */
    function __MockEVMAuthV1_init_unchained() internal onlyInitializing { }

    /// @inheritdoc TokenPurchasable
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        balances[to][id] += amount;
    }
}

contract EVMAuthTest is BaseTestWithAccessControlAndERC20s {
    MockEVMAuthV1 internal v1;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuthV1());
    }

    function _getDeploymentArtifact() internal pure override returns (string memory) {
        return "EVMAuth.t.sol:MockEVMAuthV1";
    }

    function _getInitializeCallData() internal view override returns (bytes memory) {
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](6);
        roleGrants[0] = EVMAuth.RoleGrant(UPGRADE_MANAGER_ROLE, owner);
        roleGrants[1] = EVMAuth.RoleGrant(ACCESS_MANAGER_ROLE, accessManager);
        roleGrants[2] = EVMAuth.RoleGrant(TOKEN_MANAGER_ROLE, tokenManager);
        roleGrants[3] = EVMAuth.RoleGrant(MINTER_ROLE, minter);
        roleGrants[4] = EVMAuth.RoleGrant(BURNER_ROLE, burner);
        roleGrants[5] = EVMAuth.RoleGrant(TREASURER_ROLE, treasurer);

        return abi.encodeCall(MockEVMAuthV1.initialize, (2 days, owner, treasury, roleGrants));
    }

    function _castProxy(address proxyAddress) internal override {
        v1 = MockEVMAuthV1(proxyAddress);
    }

    function _grantRoles() internal override {
        // Roles are granted during initialization
    }

    // ============ Tests ============= //

    function test_initialize() public view {
        assertEq(v1.nextTokenID(), 1);

        assertTrue(v1.hasRole(v1.UPGRADE_MANAGER_ROLE(), owner), "Upgrade manager role not set correctly");
        assertTrue(v1.hasRole(v1.ACCESS_MANAGER_ROLE(), accessManager), "Access manager role not set correctly");
        assertTrue(v1.hasRole(v1.TOKEN_MANAGER_ROLE(), tokenManager), "Token manager role not set correctly");
        assertTrue(v1.hasRole(v1.MINTER_ROLE(), minter), "Minter role not set correctly");
        assertTrue(v1.hasRole(v1.BURNER_ROLE(), burner), "Burner role not set correctly");
        assertTrue(v1.hasRole(v1.TREASURER_ROLE(), treasurer), "Treasurer role not set correctly");

        assertEq(
            keccak256(abi.encode(uint256(keccak256("tokenephemeral.storage.TokenEphemeral")) - 1))
                & ~bytes32(uint256(0xff)),
            0xec3c1253ecdf88a29ff53024f0721fc3faa1b42abcff612deb5b22d1f94e2d00
        );
    }
}
