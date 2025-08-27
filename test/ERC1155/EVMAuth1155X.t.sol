// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { EVMAuth1155X } from "src/ERC1155/EVMAuth1155X.sol";

contract EVMAuth1155X_Test is BaseTest {
    EVMAuth1155X internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth1155X.t.sol:EVMAuth1155X",
            abi.encodeCall(EVMAuth1155X.initialize, (2 days, owner, "https://token-cdn-domain/{id}.json"))
        );
        token = EVMAuth1155X(proxy);

        // Grant roles
        token.grantRole(token.UPGRADE_MANAGER_ROLE(), owner);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        vm.stopPrank();
    }
}
