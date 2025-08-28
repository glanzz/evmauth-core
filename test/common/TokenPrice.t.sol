// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "test/BaseTest.sol";
import { BaseUpgradeTest } from "test/BaseUpgradeTest.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract MockTokenPrice is TokenPrice, OwnableUpgradeable, UUPSUpgradeable {
    event MintPurchasedTokensCalled(address to, uint256 id, uint256 amount);

    function initialize(address initialOwner, address payable initialTreasury) public initializer {
        __TokenConfiguration_init();
        __TokenPrice_init(initialTreasury);
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }

    /// @inheritdoc TokenPrice
    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        emit MintPurchasedTokensCalled(to, id, amount);
    }
}

contract TokenPrice_Test is BaseTest {
    MockTokenPrice internal token;

    function setUp() public virtual override {
        super.setUp();

        // Set treasury address
        treasury = payable(makeAddr("treasury"));

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "TokenPrice.t.sol:MockTokenPrice", abi.encodeCall(MockTokenPrice.initialize, (owner, treasury))
        );
        token = MockTokenPrice(proxy);
    }
}

contract TokenPrice_UpgradeTest is BaseUpgradeTest {
    MockTokenPrice internal token;

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        // Deploy the proxy and initialize
        proxy = Upgrades.deployUUPSProxy(
            "TokenPrice.t.sol:MockTokenPrice", abi.encodeCall(MockTokenPrice.initialize, (owner, treasury))
        );
        token = MockTokenPrice(proxy);
    }

    function deployNewImplementation() internal override returns (address) {
        return address(new MockTokenPrice());
    }

    function getContractName() internal pure override returns (string memory) {
        return "TokenPrice.t.sol:MockTokenPrice";
    }

    function getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenPrice.initialize, (owner, treasury));
    }

    // TokenPrice uses Ownable instead of AccessControl
    function hasAccessControl() internal pure override returns (bool) {
        return false;
    }
}
