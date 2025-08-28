// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { BaseUpgradeTest } from "test/BaseUpgradeTest.sol";
import { TokenExpiry } from "src/common/TokenExpiry.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract MockTokenExpiry is TokenExpiry, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(address initialOwner) public initializer {
        __TokenConfiguration_init();
        __TokenExpiry_init();
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }
}

contract TokenExpiry_Test is BaseTest {
    MockTokenExpiry internal token;

    function setUp() public virtual override {
        super.setUp();

        // Deploy the proxy and initialize
        proxy =
            deployUUPSProxy("TokenExpiry.t.sol:MockTokenExpiry", abi.encodeCall(MockTokenExpiry.initialize, (owner)));
        token = MockTokenExpiry(proxy);
    }
}

contract TokenExpiry_UpgradeTest is BaseUpgradeTest {
    MockTokenExpiry internal token;

    function setToken(address proxyAddress) internal override {
        token = MockTokenExpiry(proxyAddress);
    }

    function deployNewImplementation() internal override returns (address) {
        return address(new MockTokenExpiry());
    }

    function getContractName() internal pure override returns (string memory) {
        return "TokenExpiry.t.sol:MockTokenExpiry";
    }

    function getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenExpiry.initialize, (owner));
    }
}
