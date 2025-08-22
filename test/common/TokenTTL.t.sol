// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenTTL} from "src/common/TokenTTL.sol";

contract MockTokenTTL is TokenTTL {
    constructor() TokenTTL() {}
}

contract TokenTTL_Test is Test {
    MockTokenTTL internal token;

    function setUp() public {
        token = new MockTokenTTL();
    }
}
