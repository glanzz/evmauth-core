// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TokenPurchase } from "src/common/TokenPurchase.sol";

contract MockTokenPurchase is TokenPurchase {
    function initialize(address payable initialTreasury) public initializer {
        __TokenPurchase_init(initialTreasury);
    }
}

contract TokenPurchase_Test is Test {
    MockTokenPurchase internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));

        // Deploy implementation contract
        MockTokenPurchase implementation = new MockTokenPurchase();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(MockTokenPurchase.initialize.selector, treasury);

        // Deploy proxy and initialize
        address proxyAddress = address(new ERC1967Proxy(address(implementation), initData));
        token = MockTokenPurchase(proxyAddress);
    }
}
