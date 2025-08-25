// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TokenPurchaseERC20 } from "src/common/TokenPurchaseERC20.sol";

contract MockTokenPurchaseERC20 is TokenPurchaseERC20 {
    function initialize(address payable initialTreasury) public initializer {
        __TokenPurchaseERC20_init(initialTreasury);
    }
}

contract TokenPurchaseERC20_Test is Test {
    MockTokenPurchaseERC20 internal token;

    address payable public treasury;

    function setUp() public {
        treasury = payable(makeAddr("treasury"));

        // Deploy implementation contract
        MockTokenPurchaseERC20 implementation = new MockTokenPurchaseERC20();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(MockTokenPurchaseERC20.initialize.selector, treasury);

        // Deploy proxy and initialize
        address proxyAddress = address(new ERC1967Proxy(address(implementation), initData));
        token = MockTokenPurchaseERC20(proxyAddress);
    }
}
