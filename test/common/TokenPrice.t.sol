// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";

contract MockTokenPrice is TokenPrice {
    function initialize(address payable initialTreasury) public initializer {
        __TokenPrice_init(initialTreasury);
    }
}

contract TokenPrice_Test is Test {
    MockTokenPrice internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));

        // Deploy implementation contract
        MockTokenPrice implementation = new MockTokenPrice();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(MockTokenPrice.initialize.selector, treasury);

        // Deploy proxy and initialize
        address proxyAddress = address(new ERC1967Proxy(address(implementation), initData));
        token = MockTokenPrice(proxyAddress);
    }
}
