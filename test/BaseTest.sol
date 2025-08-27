// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

abstract contract BaseTest is Test {
    address internal proxy;

    address public alice;
    address public bob;
    address public carol;

    address public owner;
    address public accessManager;
    address public tokenManager;
    address public minter;
    address public burner;
    address public treasurer;
    address payable public treasury;

    function setUp() public virtual {
        // Create user addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Create role-specific user addresses
        owner = makeAddr("owner");
        accessManager = makeAddr("accessManager");
        tokenManager = makeAddr("tokenManager");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        treasurer = makeAddr("treasurer");
        treasury = payable(makeAddr("treasury"));
    }

    function deployUUPSProxy(string memory contractName, bytes memory initializerData) internal returns (address) {
        Options memory opts;
        return Upgrades.deployUUPSProxy(contractName, initializerData, opts);
    }
}
