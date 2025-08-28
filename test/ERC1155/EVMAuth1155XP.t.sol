// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithAccessControlAndTreasury } from "test/BaseTest.sol";
import { EVMAuth1155XP } from "src/ERC1155/EVMAuth1155XP.sol";

/**
 * @dev Mock contract for testing {EVMAuth1155XP}.
 */
contract MockEVMAuth1155XP is EVMAuth1155XP {
    function initialize(
        uint48 initialDelay,
        address initialDefaultAdmin,
        string memory uri_,
        address payable initialTreasury
    ) public virtual override initializer {
        __EVMAuth1155XP_init(initialDelay, initialDefaultAdmin, uri_, initialTreasury);
    }
}

/**
 * @dev Test contract for {EVMAuth1155XP}.
 */
contract EVMAuth1155XPTest is BaseTestWithAccessControlAndTreasury {
    MockEVMAuth1155XP internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockEVMAuth1155XP());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "EVMAuth1155XP.t.sol:MockEVMAuth1155XP";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(
            MockEVMAuth1155XP.initialize, (2 days, owner, "https://example.com/api/token/{id}.json", treasury)
        );
    }

    function _setToken(address proxyAddress) internal override {
        token = MockEVMAuth1155XP(proxyAddress);
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
