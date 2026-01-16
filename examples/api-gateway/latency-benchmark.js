import dotenv from 'dotenv';
dotenv.config();

const API_BASE_URL = `http://localhost:${process.env.PORT || 3000}/api/v1`;

// Test wallet address (deployer address with tokens)
const WALLET_ADDRESS = '0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe';

const NUM_REQUESTS = 100;

async function makeAuthenticatedRequest() {
  const headers = {
    'Content-Type': 'application/json',
    'X-Wallet-Address': WALLET_ADDRESS
  };

  const startTime = Date.now();

  try {
    const response = await fetch(`${API_BASE_URL}/protected/data`, { headers });
    const data = await response.json();
    const totalLatency = Date.now() - startTime;

    // Parse verificationTime - it may come as "56ms" string, need to extract number
    let verificationTime = null;
    if (data.verificationTime) {
      const timeStr = String(data.verificationTime);
      const match = timeStr.match(/(\d+\.?\d*)/);
      verificationTime = match ? parseFloat(match[1]) : null;
    }

    return {
      success: response.ok,
      totalLatency,
      verificationTime,
      status: response.status
    };
  } catch (error) {
    return {
      success: false,
      totalLatency: Date.now() - startTime,
      verificationTime: null,
      error: error.message
    };
  }
}

function calculateStats(values) {
  if (values.length === 0) return null;

  const sorted = [...values].sort((a, b) => a - b);
  const sum = values.reduce((a, b) => a + b, 0);
  const mean = sum / values.length;

  // Calculate standard deviation
  const squaredDiffs = values.map(v => Math.pow(v - mean, 2));
  const variance = squaredDiffs.reduce((a, b) => a + b, 0) / values.length;
  const stdDev = Math.sqrt(variance);

  // Percentiles
  const p50 = sorted[Math.floor(sorted.length * 0.50)];
  const p75 = sorted[Math.floor(sorted.length * 0.75)];
  const p90 = sorted[Math.floor(sorted.length * 0.90)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];

  return {
    count: values.length,
    min: Math.min(...values),
    max: Math.max(...values),
    mean: mean,
    median: p50,
    stdDev: stdDev,
    p75: p75,
    p90: p90,
    p95: p95,
    p99: p99
  };
}

async function runBenchmark() {
  console.log('='.repeat(70));
  console.log('EVMAuth API Gateway - Latency Benchmark');
  console.log('='.repeat(70));
  console.log(`\nAPI Endpoint: ${API_BASE_URL}/protected/data`);
  console.log(`Wallet Address: ${WALLET_ADDRESS}`);
  console.log(`Number of Requests: ${NUM_REQUESTS}`);
  console.log(`\nStarting benchmark...\n`);

  const results = [];
  const verificationTimes = [];
  const totalLatencies = [];
  let successCount = 0;
  let failCount = 0;

  const overallStart = Date.now();

  // Run requests
  for (let i = 0; i < NUM_REQUESTS; i++) {
    const result = await makeAuthenticatedRequest();
    results.push(result);

    if (result.success) {
      successCount++;
      if (result.verificationTime) {
        verificationTimes.push(result.verificationTime);
      }
      totalLatencies.push(result.totalLatency);
    } else {
      failCount++;
      console.log(`  Request ${i + 1}: FAILED - ${result.error || result.status}`);
    }

    // Progress indicator every 10 requests
    if ((i + 1) % 10 === 0) {
      process.stdout.write(`  Progress: ${i + 1}/${NUM_REQUESTS} requests completed\r`);
    }
  }

  const overallTime = Date.now() - overallStart;

  console.log(`\n\nBenchmark completed in ${(overallTime / 1000).toFixed(2)}s\n`);

  // Calculate statistics
  const verificationStats = calculateStats(verificationTimes);
  const totalLatencyStats = calculateStats(totalLatencies);

  // Print results
  console.log('='.repeat(70));
  console.log('RESULTS SUMMARY');
  console.log('='.repeat(70));

  console.log(`\n✅ Successful Requests: ${successCount}/${NUM_REQUESTS} (${(successCount / NUM_REQUESTS * 100).toFixed(1)}%)`);
  if (failCount > 0) {
    console.log(`❌ Failed Requests: ${failCount}/${NUM_REQUESTS} (${(failCount / NUM_REQUESTS * 100).toFixed(1)}%)`);
  }

  console.log(`\n📊 BLOCKCHAIN VERIFICATION TIME (Read-only RPC call):`);
  console.log('─'.repeat(70));
  if (verificationStats) {
    console.log(`  Sample Size:       ${verificationStats.count} requests`);
    console.log(`  Mean:              ${verificationStats.mean.toFixed(2)}ms`);
    console.log(`  Median (P50):      ${verificationStats.median}ms`);
    console.log(`  Min:               ${verificationStats.min}ms`);
    console.log(`  Max:               ${verificationStats.max}ms`);
    console.log(`  Std Deviation:     ${verificationStats.stdDev.toFixed(2)}ms`);
    console.log(`\n  Percentiles:`);
    console.log(`    P75:             ${verificationStats.p75}ms`);
    console.log(`    P90:             ${verificationStats.p90}ms`);
    console.log(`    P95:             ${verificationStats.p95}ms`);
    console.log(`    P99:             ${verificationStats.p99}ms`);
  } else {
    console.log(`  No verification time data available`);
  }

  console.log(`\n📊 TOTAL REQUEST LATENCY (End-to-End):`);
  console.log('─'.repeat(70));
  if (totalLatencyStats) {
    console.log(`  Sample Size:       ${totalLatencyStats.count} requests`);
    console.log(`  Mean:              ${totalLatencyStats.mean.toFixed(2)}ms`);
    console.log(`  Median (P50):      ${totalLatencyStats.median}ms`);
    console.log(`  Min:               ${totalLatencyStats.min}ms`);
    console.log(`  Max:               ${totalLatencyStats.max}ms`);
    console.log(`  Std Deviation:     ${totalLatencyStats.stdDev.toFixed(2)}ms`);
    console.log(`\n  Percentiles:`);
    console.log(`    P75:             ${totalLatencyStats.p75}ms`);
    console.log(`    P90:             ${totalLatencyStats.p90}ms`);
    console.log(`    P95:             ${totalLatencyStats.p95}ms`);
    console.log(`    P99:             ${totalLatencyStats.p99}ms`);
  }

  console.log(`\n⚡ THROUGHPUT:`);
  console.log('─'.repeat(70));
  console.log(`  Requests/second:   ${(NUM_REQUESTS / (overallTime / 1000)).toFixed(2)} req/s`);
  console.log(`  Avg time/request:  ${(overallTime / NUM_REQUESTS).toFixed(2)}ms`);

  // Cold start analysis
  if (verificationTimes.length >= 10) {
    const firstRequest = verificationTimes[0];
    const subsequentRequests = verificationTimes.slice(1);
    const subsequentAvg = subsequentRequests.reduce((a, b) => a + b, 0) / subsequentRequests.length;

    console.log(`\n🔥 COLD START ANALYSIS:`);
    console.log('─'.repeat(70));
    console.log(`  First request:     ${firstRequest}ms`);
    console.log(`  Subsequent avg:    ${subsequentAvg.toFixed(2)}ms`);
    console.log(`  Cold start penalty: ${(firstRequest - subsequentAvg).toFixed(2)}ms (${((firstRequest / subsequentAvg - 1) * 100).toFixed(1)}% slower)`);
  }

  // Export data for paper
  console.log(`\n📄 DATA FOR PAPER:`);
  console.log('─'.repeat(70));
  if (verificationStats) {
    console.log(`Sample Size: ${verificationStats.count} authenticated requests`);
    console.log(`Mean Verification Time: ${verificationStats.mean.toFixed(1)}ms`);
    console.log(`Median Verification Time: ${verificationStats.median}ms`);
    console.log(`Range: ${verificationStats.min}ms - ${verificationStats.max}ms`);
    console.log(`P95: ${verificationStats.p95}ms`);
    console.log(`P99: ${verificationStats.p99}ms`);
    console.log(`Std Dev: ${verificationStats.stdDev.toFixed(2)}ms`);
  }

  console.log('\n' + '='.repeat(70));

  // Export raw data to CSV for further analysis
  console.log(`\n💾 Exporting raw data to latency-results.csv...`);
  const fs = await import('fs');
  const csvHeader = 'Request,Success,VerificationTime(ms),TotalLatency(ms)\n';
  const csvRows = results.map((r, i) =>
    `${i + 1},${r.success},${r.verificationTime || ''},${r.totalLatency}`
  ).join('\n');

  fs.writeFileSync('latency-results.csv', csvHeader + csvRows);
  console.log(`✓ Data exported successfully\n`);
}

// Check if server is running
async function checkServer() {
  try {
    const response = await fetch(`${API_BASE_URL}/public/health`);
    return response.ok;
  } catch (error) {
    return false;
  }
}

// Main execution
(async () => {
  console.log('\nChecking if API server is running...');
  const serverRunning = await checkServer();

  if (!serverRunning) {
    console.error('\n❌ ERROR: API server is not running!');
    console.error('Please start the server first with: npm start\n');
    process.exit(1);
  }

  console.log('✓ Server is running\n');
  console.log('Starting benchmark in 2 seconds...\n');

  setTimeout(runBenchmark, 2000);
})();
