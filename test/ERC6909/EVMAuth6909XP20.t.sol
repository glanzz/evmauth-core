// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithRolesAndERC20s } from "test/BaseTestWithRolesAndERC20s.sol";
import { EVMAuth6909XP20 } from "src/ERC6909/EVMAuth6909XP20.sol";

contract EVMAuth6909XP20_Test is BaseTestWithRolesAndERC20s {
    EVMAuth6909XP20 internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth6909XP20",
            abi.encodeCall(
                EVMAuth6909XP20.initialize,
                (2 days, owner, "https://contract-cdn-domain/contract-metadata.json", treasury)
            )
        );
        token = EVMAuth6909XP20(proxy);

        // Grant roles
        token.grantRole(token.UPGRADE_MANAGER_ROLE(), owner);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        // Accept USDC and Tether mock ERC-20 tokens as payment
        token.addERC20PaymentToken(address(usdc));
        token.addERC20PaymentToken(address(usdt));

        vm.stopPrank();
    }
}
