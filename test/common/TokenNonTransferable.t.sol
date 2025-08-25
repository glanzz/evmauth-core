// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TokenNonTransferable } from "src/common/TokenNonTransferable.sol";

contract MockTokenNonTransferable is TokenNonTransferable {
    function initialize() public initializer {
        __TokenNonTransferable_init();
    }
}

contract TokenNonTransferable_Test is Test {
    MockTokenNonTransferable internal token;

    function setUp() public {
        token = new MockTokenNonTransferable();
    }
}
