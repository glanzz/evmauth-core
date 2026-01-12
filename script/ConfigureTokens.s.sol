// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { EVMAuth1155 } from "src/EVMAuth1155.sol";
import { EVMAuth6909 } from "src/EVMAuth6909.sol";
import { EVMAuth } from "src/base/EVMAuth.sol";
import { TokenPurchasable } from "src/base/TokenPurchasable.sol";
import { console } from "forge-std/console.sol";

/**
 * @dev Script to configure sample token types for testnet demonstration
 */
contract ConfigureTokens1155 is Script {
    // Token IDs
    uint256 constant BASIC_API_ACCESS = 1;
    uint256 constant PREMIUM_API_ACCESS = 2;
    uint256 constant AI_AGENT_LICENSE = 3;
    uint256 constant ENTERPRISE_TIER = 4;
    uint256 constant DEVELOPER_CREDITS = 5;

    // TTL constants (in seconds)
    uint48 constant TTL_7_DAYS = 7 days;
    uint48 constant TTL_30_DAYS = 30 days;
    uint48 constant TTL_90_DAYS = 90 days;
    uint48 constant TTL_1_YEAR = 365 days;
    uint48 constant TTL_UNLIMITED = 0; // No expiration

    // Prices in wei (Base Sepolia testnet)
    uint256 constant PRICE_BASIC = 0.001 ether;      // $3 equivalent
    uint256 constant PRICE_PREMIUM = 0.005 ether;    // $15 equivalent
    uint256 constant PRICE_AI_AGENT = 0.01 ether;    // $30 equivalent
    uint256 constant PRICE_ENTERPRISE = 0.05 ether;  // $150 equivalent
    uint256 constant PRICE_CREDITS = 0.0001 ether;   // $0.30 per credit

    function run() public {
        address proxyAddress = vm.envAddress("EVMAUTH1155_PROXY");
        EVMAuth1155 evmauth = EVMAuth1155(proxyAddress);

        vm.startBroadcast();

        console.log("Configuring token types for EVMAuth1155 at:", proxyAddress);
        console.log("");

        // Token 1: Basic API Access (7-day, non-transferable)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_BASIC,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_7_DAYS,
                transferable: false
            })
        );
        console.log("Token 1: Basic API Access - 0.001 ETH, 7 days, non-transferable");

        // Token 2: Premium API Access (30-day, transferable)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_PREMIUM,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_30_DAYS,
                transferable: true
            })
        );
        console.log("Token 2: Premium API Access - 0.005 ETH, 30 days, transferable");

        // Token 3: AI Agent License (90-day, non-transferable)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_AI_AGENT,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_90_DAYS,
                transferable: false
            })
        );
        console.log("Token 3: AI Agent License - 0.01 ETH, 90 days, non-transferable");

        // Token 4: Enterprise Tier (1-year, transferable)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_ENTERPRISE,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_1_YEAR,
                transferable: true
            })
        );
        console.log("Token 4: Enterprise Tier - 0.05 ETH, 365 days, transferable");

        // Token 5: Developer Credits (unlimited, transferable)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_CREDITS,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_UNLIMITED,
                transferable: true
            })
        );
        console.log("Token 5: Developer Credits - 0.0001 ETH, unlimited, transferable");

        vm.stopBroadcast();

        console.log("Token configuration complete!");
    }
}

/**
 * @dev Script to configure sample token types for EVMAuth6909
 */
contract ConfigureTokens6909 is Script {
    // Token IDs (same as 1155 for consistency)
    uint256 constant BASIC_API_ACCESS = 1;
    uint256 constant PREMIUM_API_ACCESS = 2;
    uint256 constant AI_AGENT_LICENSE = 3;
    uint256 constant ENTERPRISE_TIER = 4;
    uint256 constant DEVELOPER_CREDITS = 5;

    // TTL constants
    uint48 constant TTL_7_DAYS = 7 days;
    uint48 constant TTL_30_DAYS = 30 days;
    uint48 constant TTL_90_DAYS = 90 days;
    uint48 constant TTL_1_YEAR = 365 days;
    uint48 constant TTL_UNLIMITED = 0;

    // Prices in wei
    uint256 constant PRICE_BASIC = 0.001 ether;
    uint256 constant PRICE_PREMIUM = 0.005 ether;
    uint256 constant PRICE_AI_AGENT = 0.01 ether;
    uint256 constant PRICE_ENTERPRISE = 0.05 ether;
    uint256 constant PRICE_CREDITS = 0.0001 ether;

    function run() public {
        address proxyAddress = vm.envAddress("EVMAUTH6909_PROXY");
        EVMAuth6909 evmauth = EVMAuth6909(proxyAddress);

        vm.startBroadcast();

        console.log("Configuring token types for EVMAuth6909 at:", proxyAddress);
        console.log("");

        // Configure 5 token types (same as 1155)
        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_BASIC,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_7_DAYS,
                transferable: false
            })
        );
        console.log("Token 1: Basic API Access - 0.001 ETH, 7 days, non-transferable");

        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_PREMIUM,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_30_DAYS,
                transferable: true
            })
        );
        console.log("Token 2: Premium API Access - 0.005 ETH, 30 days, transferable");

        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_AI_AGENT,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_90_DAYS,
                transferable: false
            })
        );
        console.log("Token 3: AI Agent License - 0.01 ETH, 90 days, non-transferable");

        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_ENTERPRISE,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_1_YEAR,
                transferable: true
            })
        );
        console.log("Token 4: Enterprise Tier - 0.05 ETH, 365 days, transferable");

        evmauth.createToken(
            EVMAuth.EVMAuthTokenConfig({
                price: PRICE_CREDITS,
                erc20Prices: new TokenPurchasable.PaymentToken[](0),
                ttl: TTL_UNLIMITED,
                transferable: true
            })
        );
        console.log("Token 5: Developer Credits - 0.0001 ETH, unlimited, transferable");

        vm.stopBroadcast();

        console.log("Token configuration complete!");
    }
}
