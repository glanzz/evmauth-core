// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TokenTTL } from "src/common/TokenTTL.sol";

contract MockTokenTTL is TokenTTL {
    function initialize() public initializer {
        __TokenTTL_init();
    }
}

contract TokenTTL_Test is Test {
    MockTokenTTL internal token;

    function setUp() public {
        token = new MockTokenTTL();
    }
}
