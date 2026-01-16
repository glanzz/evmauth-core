// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { TokenEphemeral } from "src/base/TokenEphemeral.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title SinglePurchaseScaling
 * @notice Measures gas cost of a SINGLE purchase operation at different k values
 * @dev This test pre-populates k time buckets for one user, then measures the gas
 *      for a DIFFERENT user making a single purchase. This isolates the cost of
 *      inserting into an account that already has k existing balance records.
 */

// Contract variants with different MAX_BALANCE_RECORDS values
contract EVMAuth1155_K1 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 1;
    }
}

contract EVMAuth1155_SinglePurchase_K10 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 10;
    }
}

contract EVMAuth1155_SinglePurchase_K50 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 50;
    }
}

contract EVMAuth1155_SinglePurchase_K100 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 100;
    }
}

contract EVMAuth1155_SinglePurchase_K500 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 500;
    }
}

contract EVMAuth1155_SinglePurchase_K1000 is EVMAuth1155 {
    function _maxBalanceRecords() internal pure override returns (uint256) {
        return 1000;
    }
}

contract SinglePurchaseScaling is Test {
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice"); // Used to pre-populate k buckets
    address internal bob = makeAddr("bob");     // User who makes the measured purchase
    address payable internal treasury = payable(makeAddr("treasury"));

    uint256 internal constant TTL_30_DAYS = 30 days;
    uint256 internal constant PURCHASE_PRICE = 0.1 ether;

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

    /**
     * @notice Pre-populate BOB's account with k time buckets
     * @dev Creates k distinct time buckets by warping time between mints
     */
    function _populateKBuckets(EVMAuth1155 v1, uint256 tokenId, uint256 k, address user) internal {
        if (k == 0) return;

        uint256 bucketWidth = TTL_30_DAYS / k;

        // Mint k times in different time buckets for the specified user
        for (uint256 i = 0; i < k; i++) {
            vm.warp(block.timestamp + bucketWidth);
            vm.prank(admin);
            v1.mint(user, tokenId, 100, "");
        }
    }

    /**
     * @notice Create ephemeral token with native currency payment
     */
    function _createEphemeralToken(EVMAuth1155 v1) internal returns (uint256) {
        vm.prank(admin);
        return v1.createToken(EVMAuth.EVMAuthTokenConfig({
            price: PURCHASE_PRICE,
            erc20Prices: new TokenPurchasable.PaymentToken[](0),
            ttl: uint48(TTL_30_DAYS),
            transferable: true
        }));
    }

    // ========================================================================
    // K=1 Test: Baseline with minimal bucket overhead
    // ========================================================================

    function test_SinglePurchase_K1() public {
        EVMAuth1155_K1 impl = new EVMAuth1155_K1();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        // No pre-population needed - Bob has 0 buckets, purchase creates bucket 1

        // Fund Bob and measure his purchase (1 token)
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }

    // ========================================================================
    // K=10 Test: Purchase when BOB already has 9 buckets (purchase creates 10th)
    // ========================================================================

    function test_SinglePurchase_K10() public {
        EVMAuth1155_SinglePurchase_K10 impl = new EVMAuth1155_SinglePurchase_K10();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        // Pre-populate BOB's account with 9 time buckets
        _populateKBuckets(v1, tokenId, 9, bob);

        // NOW measure Bob's purchase which inserts into account with 9 existing buckets
        // This tests the gas when Bob's account has k-1 buckets
        vm.warp(block.timestamp + 1 hours); // Move to new time bucket
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }

    // ========================================================================
    // K=50 Test: Purchase when BOB already has 49 buckets (purchase creates 50th)
    // ========================================================================

    function test_SinglePurchase_K50() public {
        EVMAuth1155_SinglePurchase_K50 impl = new EVMAuth1155_SinglePurchase_K50();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        _populateKBuckets(v1, tokenId, 49, bob);

        vm.warp(block.timestamp + 1 hours);
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }

    // ========================================================================
    // K=100 Test: Purchase when BOB already has 99 buckets (purchase creates 100th)
    // ========================================================================

    function test_SinglePurchase_K100() public {
        EVMAuth1155_SinglePurchase_K100 impl = new EVMAuth1155_SinglePurchase_K100();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        _populateKBuckets(v1, tokenId, 99, bob);

        vm.warp(block.timestamp + 1 hours);
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }

    // ========================================================================
    // K=500 Test: Purchase when BOB already has 499 buckets (purchase creates 500th)
    // ========================================================================

    function test_SinglePurchase_K500() public {
        EVMAuth1155_SinglePurchase_K500 impl = new EVMAuth1155_SinglePurchase_K500();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        _populateKBuckets(v1, tokenId, 499, bob);

        vm.warp(block.timestamp + 1 hours);
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }

    // ========================================================================
    // K=1000 Test: Purchase when BOB already has 999 buckets (purchase creates 1000th)
    // ========================================================================

    function test_SinglePurchase_K1000() public {
        EVMAuth1155_SinglePurchase_K1000 impl = new EVMAuth1155_SinglePurchase_K1000();
        EVMAuth1155 v1 = _setupContract(address(impl));
        uint256 tokenId = _createEphemeralToken(v1);

        _populateKBuckets(v1, tokenId, 999, bob);

        vm.warp(block.timestamp + 1 hours);
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        v1.purchase{ value: PURCHASE_PRICE }(tokenId, 1);
    }
}
