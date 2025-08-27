// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { EVMAuth6909X } from "src/ERC6909/EVMAuth6909X.sol";

contract EVMAuth6909X_Test is BaseTest {
    EVMAuth6909X internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth6909X.t.sol:EVMAuth6909X",
            abi.encodeCall(
                EVMAuth6909X.initialize, (2 days, owner, "https://contract-cdn-domain/contract-metadata.json")
            )
        );
        token = EVMAuth6909X(proxy);

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
