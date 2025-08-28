// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithTreasury } from "test/BaseTest.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @dev Mock contract for testing {TokenPrice}.
 */
contract MockTokenPrice is TokenPrice, OwnableUpgradeable, UUPSUpgradeable {
    event MintPurchasedTokensCalled(address to, uint256 id, uint256 amount);

    function initialize(address initialOwner, address payable initialTreasury) public initializer {
        __Ownable_init(initialOwner);
        __TokenPrice_init(initialTreasury);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }

    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        emit MintPurchasedTokensCalled(to, id, amount);
    }
}

/**
 * @dev Test contract for {TokenPrice}.
 */
contract TokenPriceTest is BaseTestWithTreasury {
    MockTokenPrice internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenPrice());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "TokenPrice.t.sol:MockTokenPrice";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenPrice.initialize, (owner, treasury));
    }

    function _setToken(address proxyAddress) internal override {
        token = MockTokenPrice(proxyAddress);
    }

    // ============ Unit Tests ============ //
}
