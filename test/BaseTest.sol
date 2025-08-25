// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

abstract contract BaseTest is Test {
    address internal proxy;

    function deployUUPSProxy(string memory contractName, bytes memory initializerData) internal returns (address) {
        Options memory opts;
        return Upgrades.deployUUPSProxy(contractName, initializerData, opts);
    }
}
