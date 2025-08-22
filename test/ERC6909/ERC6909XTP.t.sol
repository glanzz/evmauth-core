// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {ERC6909XTP} from "src/ERC6909/ERC6909XTP.sol";

contract ERC6909XTP_Test is BaseTest {
    ERC6909XTP internal token;

    function setUp() public virtual override {
        vm.startPrank(owner);
        token = new ERC6909XTP(2 days, owner, "https://token-cdn-domain/{id}.json", treasury);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }
}
