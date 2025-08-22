// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {EVMAuth6909P} from "src/EVMAuth/6909/EVMAuth6909P.sol";

contract EVMAuth6909P_Test is BaseTest {
    EVMAuth6909P internal token;

    function setUp() public virtual override {
        vm.startPrank(owner);
        token = new EVMAuth6909P(2 days, owner, "https://token-cdn-domain/{id}.json", treasury);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }
}
