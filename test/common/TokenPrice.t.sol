// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenPrice} from "src/common/TokenPrice.sol";

contract MockTokenPrice is TokenPrice {
    constructor(address payable initialTreasury) TokenPrice(initialTreasury) {}
}

contract TokenPrice_Test is Test {
    MockTokenPrice internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));
        token = new MockTokenPrice(treasury);
    }
}
