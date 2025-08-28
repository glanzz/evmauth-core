// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithAccessControl } from "test/BaseTest.sol";
import { EVMAuth6909X } from "src/ERC6909/EVMAuth6909X.sol";

/**
 * @dev Mock contract for testing {EVMAuth6909X}.
 */
contract MockEVMAuth6909X is EVMAuth6909X {
    function initialize(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        virtual
        override
        initializer
    {
        __EVMAuth6909X_init(initialDelay, initialDefaultAdmin, uri_);
    }
}

/**
 * @dev Test contract for {EVMAuth6909X}.
 */
contract EVMAuth6909XTest is BaseTestWithAccessControl {
    MockEVMAuth6909X internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuth6909X());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "EVMAuth6909X.t.sol:MockEVMAuth6909X";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockEVMAuth6909X.initialize, (2 days, owner, "https://example.com/contract-metadata"));
    }

    function _setToken(address proxyAddress) internal override {
        token = MockEVMAuth6909X(proxyAddress);
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
