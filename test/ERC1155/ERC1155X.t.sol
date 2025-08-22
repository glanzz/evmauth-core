// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {ERC1155X} from "src/ERC1155/ERC1155X.sol";

contract ERC1155X_Test is BaseTest {
    ERC1155X internal token;

    function setUp() public virtual override {
        vm.startPrank(owner);
        token = new ERC1155X(2 days, owner, "https://token-cdn-domain/{id}.json");
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }
}
