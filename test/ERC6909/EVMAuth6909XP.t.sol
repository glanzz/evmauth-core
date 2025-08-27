// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithRoles } from "test/BaseTestWithRoles.sol";
import { EVMAuth6909XP } from "src/ERC6909/EVMAuth6909XP.sol";

contract EVMAuth6909XP_Test is BaseTestWithRoles {
    EVMAuth6909XP internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth6909XP",
            abi.encodeCall(
                EVMAuth6909XP.initialize,
                (2 days, owner, "https://contract-cdn-domain/contract-metadata.json", treasury)
            )
        );
        token = EVMAuth6909XP(proxy);

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
