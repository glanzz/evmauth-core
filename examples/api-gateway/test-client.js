import dotenv from 'dotenv';
dotenv.config();

const API_BASE_URL = `http://localhost:${process.env.PORT || 3000}/api/v1`;

// Test wallet address (deployer address with tokens)
const WALLET_ADDRESS = '0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe';

async function testEndpoint(name, endpoint, requiresAuth = false) {
  const headers = {
    'Content-Type': 'application/json'
  };

  if (requiresAuth) {
    headers['X-Wallet-Address'] = WALLET_ADDRESS;
  }

  const startTime = Date.now();

  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, { headers });
    const latency = Date.now() - startTime;
    const data = await response.json();

    console.log(`\n${name}:`);
    console.log(`  Status: ${response.status} ${response.statusText}`);
    console.log(`  Latency: ${latency}ms`);

    if (response.ok) {
      console.log(`  ✓ Success`);
      if (data.verificationTime) {
        console.log(`  Verification Time: ${data.verificationTime}ms`);
      }
    } else {
      console.log(`  ✗ Failed: ${data.message || data.error}`);
    }

    return { success: response.ok, latency, verificationTime: data.verificationTime };
  } catch (error) {
    console.log(error);
    const latency = Date.now() - startTime;
    console.log(`\n${name}:`);
    console.log(`  ✗ Error: ${error.message}`);
    console.log(`  Latency: ${latency}ms`);
    return { success: false, latency, error: error.message };
  }
}

async function runTests() {
  console.log('='.repeat(60));
  console.log('EVMAuth API Gateway - Integration Tests');
  console.log('='.repeat(60));
  console.log(`\nTesting API at: ${API_BASE_URL}`);
  console.log(`Wallet Address: ${WALLET_ADDRESS}\n`);

  const results = [];

  // Test 1: Public health endpoint
  results.push(await testEndpoint('Test 1: Public Health Check', '/public/health', false));

  //  Test 2: Public info endpoint
  results.push(await testEndpoint('Test 2: Public Info', '/public/info', false));

  // Test 3: Protected endpoint WITHOUT token (should fail)
  console.log(`\nTest 3: Protected Endpoint (No Auth)`);
  try {
    const response = await fetch(`${API_BASE_URL}/protected/data`);
    const data = await response.json();
    console.log(`  Status: ${response.status}`);
    console.log(`  ${response.ok ? '✗ Should have failed' : '✓ Correctly denied'}`);
    results.push({ success: !response.ok, latency: 0 });
  } catch (error) {
    console.log(`  ✗ Error: ${error.message}`);
    results.push({ success: false, latency: 0 });
  }

  // Test 4: Protected endpoint WITH token (should succeed)
  results.push(await testEndpoint('Test 4: Protected Data (With Token)', '/protected/data', true));

  // Test 5: Premium endpoint WITH token
  results.push(await testEndpoint('Test 5: Premium Data (With Token)', '/protected/premium', true));

  // Test 6: Multiple requests for latency measurement
  console.log(`\nTest 6: Latency Measurement (10 requests)`);
  const latencies = [];

  for (let i = 0; i < 10; i++) {
    const result = await testEndpoint(`  Request ${i + 1}`, '/protected/data', true);
    if (result.verificationTime) {
      latencies.push(result.verificationTime);
    }
  }

  if (latencies.length > 0) {
    const avg = latencies.reduce((a, b) => a + b, 0) / latencies.length;
    const min = Math.min(...latencies);
    const max = Math.max(...latencies);

    console.log(`\n  Average verification time: ${avg.toFixed(2)}ms`);
    console.log(`  Min: ${min}ms, Max: ${max}ms`);

    results.push({ success: true, avgLatency: avg, minLatency: min, maxLatency: max });
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('Test Summary');
  console.log('='.repeat(60));

  const successful = results.filter(r => r.success).length;
  console.log(`\nTests Passed: ${successful}/${results.length}`);

  if (latencies.length > 0) {
    console.log(`\n📊 Performance Metrics:`);
    console.log(`  Average Verification Latency: ${(latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2)}ms`);
    console.log(`  Min Latency: ${Math.min(...latencies)}ms`);
    console.log(`  Max Latency: ${Math.max(...latencies)}ms`);
  }

  console.log('\n' + '='.repeat(60));
}

// Run tests
console.log('Starting API Gateway tests in 2 seconds...\n');
setTimeout(runTests, 2000);
