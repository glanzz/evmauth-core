// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {EVMAuth1155P20} from "src/EVMAuth/1155/EVMAuth1155P20.sol";

contract EVMAuth1155P20_Test is BaseTest {
    EVMAuth1155P20 internal token;

    function setUp() public virtual override {
        vm.startPrank(owner);
        token = new EVMAuth1155P20(2 days, owner, "https://token-cdn-domain/{id}.json", treasury);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }
}
