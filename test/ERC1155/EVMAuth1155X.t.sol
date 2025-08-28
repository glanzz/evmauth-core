// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithAccessControl } from "test/BaseTest.sol";
import { EVMAuth1155X } from "src/ERC1155/EVMAuth1155X.sol";

/**
 * @dev Mock contract for testing {EVMAuth1155X}.
 */
contract MockEVMAuth1155X is EVMAuth1155X {
    function initialize(uint48 initialDelay, address initialDefaultAdmin, string memory uri_)
        public
        virtual
        override
        initializer
    {
        __EVMAuth1155X_init(initialDelay, initialDefaultAdmin, uri_);
    }
}

/**
 * @dev Test contract for {EVMAuth1155X}.
 */
contract EVMAuth1155XTest is BaseTestWithAccessControl {
    MockEVMAuth1155X internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuth1155X());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "EVMAuth1155X.t.sol:MockEVMAuth1155X";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockEVMAuth1155X.initialize, (2 days, owner, "https://example.com/api/token/{id}.json"));
    }

    function _setToken(address proxyAddress) internal override {
        token = MockEVMAuth1155X(proxyAddress);
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
