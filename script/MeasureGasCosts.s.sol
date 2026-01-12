// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title MeasureGasCosts
 * @notice Script to measure actual gas costs for EVMAuth operations on Base Sepolia
 * @dev Run with: forge script script/MeasureGasCosts.s.sol --rpc-url base-sepolia --broadcast --verify
 *
 * Deployed Contracts on Base Sepolia:
 * - EVMAuth1155: 0x67b8dD172f50784F6eaffe27d4f79360e44367eC
 * - EVMAuth6909: 0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539
 */

struct PaymentToken {
    address token;
    uint256 price;
}

struct EVMAuthTokenConfig {
    uint256 price;
    PaymentToken[] erc20Prices;
    uint256 ttl;
    bool transferable;
}

interface IERC1155 {
    function createToken(EVMAuthTokenConfig calldata config) external returns (uint256 id);
    function updateToken(uint256 id, EVMAuthTokenConfig calldata config) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
    function pause() external;
    function unpause() external;
    function freezeAccount(address account) external;
    function unfreezeAccount(address account) external;
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function paused() external view returns (bool);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function isAccountFrozen(address account) external view returns (bool);
}

interface IERC6909 {
    function createToken(EVMAuthTokenConfig calldata config) external returns (uint256 id);
    function updateToken(uint256 id, EVMAuthTokenConfig calldata config) external;
    function transfer(address to, uint256 id, uint256 amount) external returns (bool);
    function pause() external;
    function unpause() external;
    function freezeAccount(address account) external;
    function unfreezeAccount(address account) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function paused() external view returns (bool);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function isAccountFrozen(address account) external view returns (bool);
}

contract MeasureGasCosts is Script {
    // Deployed contract addresses on Base Sepolia
    address constant EVMAUTH_1155 = 0x67b8dD172f50784F6eaffe27d4f79360e44367eC;
    address constant EVMAUTH_6909 = 0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539;

    IERC1155 evmauth1155;
    IERC6909 evmauth6909;

    struct GasResults {
        uint256 createToken;
        uint256 updateToken;
        uint256 transfer;
        uint256 batchTransfer5;
        uint256 pause;
        uint256 unpause;
        uint256 freezeAccount;
        uint256 unfreezeAccount;
        uint256 mint;
        uint256 burn;
    }

    function setUp() public {
        evmauth1155 = IERC1155(EVMAUTH_1155);
        evmauth6909 = IERC6909(EVMAUTH_6909);
    }

    function run() public {
        console.log("=================================================================");
        console.log("EVMAuth Gas Cost Measurements - Base Sepolia");
        console.log("=================================================================");
        console.log("Signer:", msg.sender);
        console.log("");

        vm.startBroadcast();

        GasResults memory results1155 = measureERC1155();
        GasResults memory results6909 = measureERC6909(msg.sender);

        vm.stopBroadcast();

        // Print summary for paper table
        printSummary(results1155, results6909);
    }

    function measureERC1155() internal returns (GasResults memory results) {
        console.log("=================================================================");
        console.log("Measuring EVMAuth1155 (ERC-1155)");
        console.log("Contract:", EVMAUTH_1155);
        console.log("=================================================================");

        address testRecipient = makeAddr("recipient_1155");
        address testFreezeAddr = makeAddr("freeze_1155");

        PaymentToken[] memory emptyERC20Prices = new PaymentToken[](0);
        EVMAuthTokenConfig memory config = EVMAuthTokenConfig({
            price: 0.002 ether,
            erc20Prices: emptyERC20Prices,
            ttl: 14 days,
            transferable: true
        });

        // 1. Create Token (create new token type)
        console.log("1. createToken...");
        uint256 gasBefore = gasleft();
        uint256 newTokenId = evmauth1155.createToken(config);
        results.createToken = gasBefore - gasleft();
        console.log("   Gas:", results.createToken);
        console.log("   Created Token ID:", newTokenId);

        // 2. Update Token (updates price, TTL, transferability)
        console.log("2. updateToken...");
        gasBefore = gasleft();
        evmauth1155.updateToken(1, config);
        results.updateToken = gasBefore - gasleft();
        console.log("   Gas:", results.updateToken);

        // 2. Mint (for transfer test)
        console.log("2. mint...");
        gasBefore = gasleft();
        evmauth1155.mint(msg.sender, 1, 1, "");
        results.mint = gasBefore - gasleft();
        console.log("   Gas:", results.mint);

        // 4. Single Transfer
        console.log("4. transfer (safeTransferFrom)...");
        gasBefore = gasleft();
        evmauth1155.safeTransferFrom(msg.sender, testRecipient, 1, 1, "");
        results.transfer = gasBefore - gasleft();
        console.log("   Gas:", results.transfer);

        // 5. Batch Transfer - Skipped (tokens are non-transferable by config)
        console.log("5. batchTransfer - Skipped");
        results.batchTransfer5 = 0;

        // 6. Burn
        console.log("6. burn...");
        evmauth1155.mint(msg.sender, 1, 1, ""); // Mint one to burn
        gasBefore = gasleft();
        evmauth1155.burn(msg.sender, 1, 1);
        results.burn = gasBefore - gasleft();
        console.log("   Gas:", results.burn);

        // 7. Pause
        console.log("7. pause...");
        if (!evmauth1155.paused()) {
            gasBefore = gasleft();
            evmauth1155.pause();
            results.pause = gasBefore - gasleft();
            console.log("   Gas:", results.pause);
        }

        // 8. Unpause
        console.log("8. unpause...");
        if (evmauth1155.paused()) {
            gasBefore = gasleft();
            evmauth1155.unpause();
            results.unpause = gasBefore - gasleft();
            console.log("   Gas:", results.unpause);
        }

        // 9. Freeze Account
        console.log("9. freezeAccount...");
        gasBefore = gasleft();
        evmauth1155.freezeAccount(testFreezeAddr);
        results.freezeAccount = gasBefore - gasleft();
        console.log("   Gas:", results.freezeAccount);

        // 10. Unfreeze Account
        console.log("10. unfreezeAccount...");
        gasBefore = gasleft();
        evmauth1155.unfreezeAccount(testFreezeAddr);
        results.unfreezeAccount = gasBefore - gasleft();
        console.log("   Gas:", results.unfreezeAccount);

        console.log("");
        return results;
    }

    function measureERC6909(address deployer) internal returns (GasResults memory results) {
        console.log("=================================================================");
        console.log("Measuring EVMAuth6909 (ERC-6909)");
        console.log("Contract:", EVMAUTH_6909);
        console.log("=================================================================");

        address testRecipient = makeAddr("recipient_6909");
        address testFreezeAddr = makeAddr("freeze_6909");

        PaymentToken[] memory emptyERC20Prices = new PaymentToken[](0);
        EVMAuthTokenConfig memory config = EVMAuthTokenConfig({
            price: 0.002 ether,
            erc20Prices: emptyERC20Prices,
            ttl: 14 days,
            transferable: true
        });

        // 1. Create Token (create new token type)
        console.log("1. createToken...");
        uint256 gasBefore = gasleft();
        uint256 newTokenId = evmauth6909.createToken(config);
        results.createToken = gasBefore - gasleft();
        console.log("   Gas:", results.createToken);
        console.log("   Created Token ID:", newTokenId);

        // 2. Update Token
        console.log("2. updateToken...");
        gasBefore = gasleft();
        evmauth6909.updateToken(1, config);
        results.updateToken = gasBefore - gasleft();
        console.log("   Gas:", results.updateToken);

        // 2. Mint (for transfer test)
        console.log("3. mint...");
        gasBefore = gasleft();
        evmauth6909.mint(deployer, 1, 1);
        results.mint = gasBefore - gasleft();
        console.log("   Gas:", results.mint);

        // 4. Single Transfer
        console.log("4. transfer...");
        gasBefore = gasleft();
        evmauth6909.transfer(testRecipient, 1, 1);
        results.transfer = gasBefore - gasleft();
        console.log("   Gas:", results.transfer);

        // Note: ERC-6909 doesn't have native batch transfer, so we skip it
        console.log("5. batchTransfer - N/A for ERC-6909 (no native batch)");
        results.batchTransfer5 = 0;

        // 6. Burn
        console.log("6. burn...");
        evmauth6909.mint(deployer, 1, 1); // Mint one to burn
        gasBefore = gasleft();
        evmauth6909.burn(deployer, 1, 1);
        results.burn = gasBefore - gasleft();
        console.log("   Gas:", results.burn);

        // 7. Pause
        console.log("7. pause...");
        if (!evmauth6909.paused()) {
            gasBefore = gasleft();
            evmauth6909.pause();
            results.pause = gasBefore - gasleft();
            console.log("   Gas:", results.pause);
        }

        // 8. Unpause
        console.log("8. unpause...");
        if (evmauth6909.paused()) {
            gasBefore = gasleft();
            evmauth6909.unpause();
            results.unpause = gasBefore - gasleft();
            console.log("   Gas:", results.unpause);
        }

        // 9. Freeze Account
        console.log("9. freezeAccount...");
        gasBefore = gasleft();
        evmauth6909.freezeAccount(testFreezeAddr);
        results.freezeAccount = gasBefore - gasleft();
        console.log("   Gas:", results.freezeAccount);

        // 10. Unfreeze Account
        console.log("10. unfreezeAccount...");
        gasBefore = gasleft();
        evmauth6909.unfreezeAccount(testFreezeAddr);
        results.unfreezeAccount = gasBefore - gasleft();
        console.log("   Gas:", results.unfreezeAccount);

        console.log("");
        return results;
    }

    function printSummary(GasResults memory r1155, GasResults memory r6909) internal pure {
        console.log("=================================================================");
        console.log("SUMMARY FOR PAPER TABLE");
        console.log("=================================================================");
        console.log("ERC-1155 Results:");
        console.log("  createToken:", r1155.createToken);
        console.log("  updateToken:", r1155.updateToken);
        console.log("  mint:", r1155.mint);
        console.log("  transfer:", r1155.transfer);
        console.log("  burn:", r1155.burn);
        console.log("  batchTransfer(5):", r1155.batchTransfer5);
        console.log("  pause:", r1155.pause);
        console.log("  unpause:", r1155.unpause);
        console.log("  freezeAccount:", r1155.freezeAccount);
        console.log("  unfreezeAccount:", r1155.unfreezeAccount);
        console.log("");
        console.log("ERC-6909 Results:");
        console.log("  createToken:", r6909.createToken);
        console.log("  updateToken:", r6909.updateToken);
        console.log("  mint:", r6909.mint);
        console.log("  transfer:", r6909.transfer);
        console.log("  burn:", r6909.burn);
        console.log("  pause:", r6909.pause);
        console.log("  unpause:", r6909.unpause);
        console.log("  freezeAccount:", r6909.freezeAccount);
        console.log("  unfreezeAccount:", r6909.unfreezeAccount);
        console.log("=================================================================");
    }
}
