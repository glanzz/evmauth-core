// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { ERC6909XT } from "src/ERC6909/ERC6909XT.sol";

contract ERC6909XT_Test is BaseTest {
    ERC6909XT internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy implementation contract
        ERC6909XT implementation = new ERC6909XT();

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSelector(ERC6909XT.initialize.selector, 2 days, owner, "https://token-cdn-domain/{id}.json");

        // Deploy proxy and initialize
        address proxyAddress = deployProxy(address(implementation), initData);
        token = ERC6909XT(proxyAddress);

        // Grant roles
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        vm.stopPrank();
    }
}
