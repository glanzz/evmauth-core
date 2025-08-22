// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenNonTransferable} from "src/common/TokenNonTransferable.sol";

contract MockTokenNonTransferable is TokenNonTransferable {
    constructor() TokenNonTransferable() {}
}

contract TokenNonTransferable_Test is Test {
    MockTokenNonTransferable internal token;

    function setUp() public {
        token = new MockTokenNonTransferable();
    }
}
