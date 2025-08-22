// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "test/BaseTest.sol";
import {TokenAccessControl} from "src/common/TokenAccessControl.sol";

contract MockTokenAccessControl is TokenAccessControl {
    constructor(uint48 initialDelay, address initialDefaultAdmin)
        TokenAccessControl(initialDelay, initialDefaultAdmin)
    {}
}

contract TokenAccessControl_Test is BaseTest {
    MockTokenAccessControl internal token;

    function setUp() public virtual override {
        vm.startPrank(owner);
        token = new MockTokenAccessControl(2 days, owner);
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);
        vm.stopPrank();
    }
}
