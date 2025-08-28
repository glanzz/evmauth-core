// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithAccessControlAndTreasury } from "test/BaseTest.sol";
import { EVMAuth6909XP } from "src/ERC6909/EVMAuth6909XP.sol";

/**
 * @dev Mock contract for testing {EVMAuth6909XP}.
 */
contract MockEVMAuth6909XP is EVMAuth6909XP {
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public virtual override initializer {
        __EVMAuth6909XP_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }
}

/**
 * @dev Test contract for {EVMAuth6909XP}.
 */
contract EVMAuth6909XPTest is BaseTestWithAccessControlAndTreasury {
    MockEVMAuth6909XP internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuth6909XP());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "EVMAuth6909XP.t.sol:MockEVMAuth6909XP";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(
            MockEVMAuth6909XP.initialize, (2 days, owner, "https://example.com/contract-metadata", treasury)
        );
    }

    function _setToken(address proxyAddress) internal override {
        token = MockEVMAuth6909XP(proxyAddress);
    }

    function _grantRoles() internal override {
        vm.startPrank(owner);
        token.grantRole(token.UPGRADE_MANAGER_ROLE(), owner);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }

    // ============ Unit Tests ============ //
}
