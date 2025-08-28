// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithAccessControlAndTreasury } from "test/BaseTest.sol";
import { EVMAuth1155P } from "src/ERC1155/EVMAuth1155P.sol";

/**
 * @dev Mock contract for testing {EVMAuth1155P}.
 */
contract MockEVMAuth1155P is EVMAuth1155P {
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public virtual override initializer {
        __EVMAuth1155P_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }
}

/**
 * @dev Test contract for {EVMAuth1155P}.
 */
contract EVMAuth1155Test is BaseTestWithAccessControlAndTreasury {
    MockEVMAuth1155P internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuth1155P());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "EVMAuth1155P.t.sol:MockEVMAuth1155P";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(
            MockEVMAuth1155P.initialize, (2 days, owner, "https://example.com/api/token/{id}.json", treasury)
        );
    }

    function _setToken(address proxyAddress) internal override {
        token = MockEVMAuth1155P(proxyAddress);
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
