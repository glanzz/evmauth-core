// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithERC20s } from "test/BaseTest.sol";
import { EVMAuth1155P20 } from "src/ERC1155/EVMAuth1155P20.sol";

contract EVMAuth1155P20_Test is BaseTestWithERC20s {
    EVMAuth1155P20 internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "EVMAuth1155P20.t.sol:EVMAuth1155P20",
            abi.encodeCall(EVMAuth1155P20.initialize, (2 days, owner, "https://token-cdn-domain/{id}.json", treasury))
        );
        token = EVMAuth1155P20(proxy);

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
