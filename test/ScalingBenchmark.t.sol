// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ScalingBenchmark
 * @notice Benchmarks to measure gas costs at different k values (MAX_BALANCE_RECORDS)
 */
contract EVMAuth1155_K10 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 10;
    }
}

contract EVMAuth1155_K50 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 50;
    }
}

contract EVMAuth1155_K100 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 100;
    }
}

contract EVMAuth1155_K200 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 200;
    }
}

contract ScalingBenchmark is Test {
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address payable internal treasury = payable(makeAddr("treasury"));

    uint256 internal constant TTL_30_DAYS = 30 days;

    function _setupContract(address implementation) internal returns (EVMAuth1155) {
        EVMAuth.RoleGrant[] memory roleGrants = new EVMAuth.RoleGrant[](2);
        roleGrants[0] = EVMAuth.RoleGrant(keccak256("MINTER_ROLE"), admin);
        roleGrants[1] = EVMAuth.RoleGrant(keccak256("TOKEN_MANAGER_ROLE"), admin);

        bytes memory initData = abi.encodeWithSelector(
            EVMAuth1155.initialize.selector,
            2 days,  // initialDelay
            admin,  // initialDefaultAdmin
            treasury,  // initialTreasury
            roleGrants,  // roleGrants
            "https://token/{id}.json"  // uri
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        return EVMAuth1155(address(proxy));
    }

    function _fillBalanceRecords(EVMAuth1155 v1, uint256 tokenId, uint256 k) internal {
        uint256 bucketWidth = TTL_30_DAYS / k;

        // Fill up to k records by minting in different time buckets
        for (uint256 i = 0; i < k; i++) {
            vm.warp(block.timestamp + bucketWidth);
            vm.prank(admin);
            v1.mint(alice, tokenId, 100, "");
        }
    }

    function test_K10_pruneGas() public {
        EVMAuth1155_K10 impl = new EVMAuth1155_K10();
        EVMAuth1155 v1 = _setupContract(address(impl));

        // Create ephemeral token
        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 10);

        // Warp past expiration
        vm.warp(block.timestamp + TTL_30_DAYS + 1);

        // Measure prune gas
        vm.prank(alice);
        v1.pruneBalanceRecords(alice, tokenId);
    }

    function test_K10_worstCaseTransfer() public {
        EVMAuth1155_K10 impl = new EVMAuth1155_K10();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 10);

        // Worst case: transfer all tokens (iterates through all k records)
        uint256 balance = v1.balanceOf(alice, tokenId);
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, balance, "");
    }

    function test_K50_pruneGas() public {
        EVMAuth1155_K50 impl = new EVMAuth1155_K50();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 50);
        vm.warp(block.timestamp + TTL_30_DAYS + 1);

        vm.prank(alice);
        v1.pruneBalanceRecords(alice, tokenId);
    }

    function test_K50_worstCaseTransfer() public {
        EVMAuth1155_K50 impl = new EVMAuth1155_K50();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 50);

        uint256 balance = v1.balanceOf(alice, tokenId);
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, balance, "");
    }

    function test_K100_pruneGas() public {
        EVMAuth1155_K100 impl = new EVMAuth1155_K100();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 100);
        vm.warp(block.timestamp + TTL_30_DAYS + 1);

        vm.prank(alice);
        v1.pruneBalanceRecords(alice, tokenId);
    }

    function test_K100_worstCaseTransfer() public {
        EVMAuth1155_K100 impl = new EVMAuth1155_K100();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 100);

        uint256 balance = v1.balanceOf(alice, tokenId);
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, balance, "");
    }

    function test_K200_pruneGas() public {
        EVMAuth1155_K200 impl = new EVMAuth1155_K200();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 200);
        vm.warp(block.timestamp + TTL_30_DAYS + 1);

        vm.prank(alice);
        v1.pruneBalanceRecords(alice, tokenId);
    }

    function test_K200_worstCaseTransfer() public {
        EVMAuth1155_K200 impl = new EVMAuth1155_K200();
        EVMAuth1155 v1 = _setupContract(address(impl));

        vm.prank(admin);
        uint256 tokenId = v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: 1 ether,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));

        _fillBalanceRecords(v1, tokenId, 200);

        uint256 balance = v1.balanceOf(alice, tokenId);
        vm.prank(alice);
        v1.safeTransferFrom(alice, bob, tokenId, balance, "");
    }
}
