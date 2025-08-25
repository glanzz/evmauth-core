// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { ERC1155XP } from "src/ERC1155/ERC1155XP.sol";

contract ERC1155XP_Test is BaseTest {
    ERC1155XP internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy implementation contract
        ERC1155XP implementation = new ERC1155XP();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            ERC1155XP.initialize.selector, 2 days, owner, "https://token-cdn-domain/{id}.json", treasury
        );

        // Deploy proxy and initialize
        address proxyAddress = deployProxy(address(implementation), initData);
        token = ERC1155XP(proxyAddress);

        // Grant roles
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        vm.stopPrank();
    }
}
