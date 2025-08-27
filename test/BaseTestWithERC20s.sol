// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract BaseTestWithERC20s is BaseTest {
    ERC20Mock internal usdc;
    ERC20Mock internal usdt;

    function setUp() public virtual override {
        super.setUp();

        // Deploy mock ERC-20 tokens
        usdc = new ERC20Mock();
        usdt = new ERC20Mock();
    }
}
