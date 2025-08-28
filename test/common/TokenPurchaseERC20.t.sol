// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithERC20s } from "test/BaseTest.sol";
import { TokenPrice } from "src/common/TokenPrice.sol";
import { TokenPurchaseERC20 } from "src/common/TokenPurchaseERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @dev Mock contract for testing {TokenPurchaseERC20}.
 */
contract MockTokenPurchaseERC20 is TokenPurchaseERC20, OwnableUpgradeable, UUPSUpgradeable {
    event MintPurchasedTokensCalled(address to, uint256 id, uint256 amount);

    function initialize(address initialOwner, address payable initialTreasury) public initializer {
        __Ownable_init(initialOwner);
        __TokenPurchaseERC20_init(initialTreasury);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        // This will revert if the caller is not the owner
    }

    function _mintPurchasedTokens(address to, uint256 id, uint256 amount) internal virtual override {
        emit MintPurchasedTokensCalled(to, id, amount);
    }
}

/**
 * @dev Test contract for {TokenPurchaseERC20}.
 */
contract TokenPurchaseERC20Test is BaseTestWithERC20s {
    MockTokenPurchaseERC20 internal token;

    // =========== Test Setup ============ //

    function _deployNewImplementation() internal override returns (address) {
        return address(new MockTokenPurchaseERC20());
    }

    function _getContractName() internal pure override returns (string memory) {
        return "TokenPurchaseERC20.t.sol:MockTokenPurchaseERC20";
    }

    function _getInitializerData() internal view override returns (bytes memory) {
        return abi.encodeCall(MockTokenPurchaseERC20.initialize, (owner, treasury));
    }

    function _setToken(address proxyAddress) internal override {
        token = MockTokenPurchaseERC20(proxyAddress);
    }

    // ============ Unit Tests ============ //
}
