// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithRoles } from "test/BaseTestWithRoles.sol";
import { EVMAuth1155TP } from "src/ERC1155/EVMAuth1155TP.sol";

contract EVMAuth1155TP_Test is BaseTestWithRoles {
    EVMAuth1155TP internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth1155TP",
            abi.encodeCall(EVMAuth1155TP.initialize, (2 days, owner, "https://token-cdn-domain/{id}.json", treasury))
        );
        token = EVMAuth1155TP(proxy);

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
