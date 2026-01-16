#!/usr/bin/env python3
"""
Deployment Waterfall Chart
Shows cumulative gas costs for complete EVMAuth system setup
"""

import matplotlib.pyplot as plt
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10
plt.rcParams['axes.labelsize'] = 11
plt.rcParams['axes.titlesize'] = 12

# Deployment steps and their gas costs (ERC-1155 as example)
# Total: 8,212,855 gas
steps = [
    'Start',
    'Deploy\nProxy',
    'Deploy\nImplementation',
    'Token 1:\nBasic',
    'Token 2:\nPremium',
    'Token 3:\nAI Agent',
    'Token 4:\nEnterprise',
    'Token 5:\nDev Credits',
    'First\nPurchase',
    'Total'
]

# Gas costs for each step (in thousands)
# Proxy: 205K, Implementation: 5355K, Each token config: ~530K, First purchase: 148K
costs = [0, 205, 5355, 530, 530, 530, 530, 530, 148, 0]  # in thousands

# Calculate cumulative values
cumulative = [0]
for i in range(1, len(costs)):
    if i < len(costs) - 1:  # Not the total
        cumulative.append(cumulative[-1] + costs[i])
    else:  # Total
        cumulative.append(cumulative[-1])

# Prepare data for waterfall
x = np.arange(len(steps))
bottoms = [0] * len(steps)
heights = costs.copy()

# Adjust for waterfall effect
for i in range(1, len(steps) - 1):
    bottoms[i] = cumulative[i-1]
    heights[i] = costs[i]

# Final bar shows total
bottoms[-1] = 0
heights[-1] = cumulative[-1]

# Create colors: start (white), increments (blue), total (green)
colors = ['lightgray']  # Start
colors += ['#2E86AB'] * 7  # All increment steps
colors += ['#6A994E']  # Total

fig, ax = plt.subplots(figsize=(12, 7))

# Create waterfall bars
bars = ax.bar(x, heights, bottom=bottoms, color=colors, edgecolor='black',
              linewidth=1.5, width=0.8)

# Draw connecting lines between bars
for i in range(len(steps) - 2):
    ax.plot([i + 0.4, i + 1.4],
            [cumulative[i], cumulative[i]],
            'k--', linewidth=1, alpha=0.5)

# Customize axes
ax.set_xticks(x)
ax.set_xticklabels(steps, rotation=0, ha='center', fontsize=9)
ax.set_ylabel('Gas Cost (thousands)', fontweight='bold')
ax.set_title('EVMAuth Deployment Waterfall: Complete System Setup', fontweight='bold', pad=15)
ax.grid(True, axis='y', alpha=0.3, linestyle='--', linewidth=0.5)

# Add value labels on bars
for i, (bar, cost, cumul) in enumerate(zip(bars, costs, cumulative)):
    if i == 0:  # Start
        ax.text(i, bar.get_height()/2, 'Start',
                ha='center', va='center', fontweight='bold', fontsize=9)
    elif i == len(bars) - 1:  # Total
        ax.text(i, bar.get_height()/2, f'Total:\n{int(cumul)}K gas',
                ha='center', va='center', fontweight='bold', fontsize=10, color='white')
    else:  # Increment steps
        # Show increment value
        ax.text(i, bottoms[i] + heights[i]/2, f'+{int(cost)}K',
                ha='center', va='center', fontweight='bold', fontsize=8, color='white')

        # Show cumulative value above bar
        if cost > 100:  # Only for significant increments
            ax.text(i, bottoms[i] + heights[i] + 150,
                    f'{int(cumul)}K',
                    ha='center', va='bottom', fontsize=8,
                    bbox=dict(boxstyle='round,pad=0.2', facecolor='lightyellow', alpha=0.8, edgecolor='none'))

# Add phase annotations
ax.annotate('', xy=(0.6, 7000), xytext=(1.4, 7000),
            arrowprops=dict(arrowstyle='<->', lw=2, color='red'))
ax.text(1, 7200, 'Contract\nDeployment', ha='center', fontsize=9, color='red', fontweight='bold')

ax.annotate('', xy=(2.6, 7000), xytext=(6.4, 7000),
            arrowprops=dict(arrowstyle='<->', lw=2, color='orange'))
ax.text(4.5, 7200, 'Token Configuration\n(5 access tiers)', ha='center', fontsize=9, color='orange', fontweight='bold')

# Add cost calculation
eth_price = 2500
gas_price_gwei = 0.15
total_gas = cumulative[-1] * 1000  # Convert back to actual gas
cost_usd = (total_gas * gas_price_gwei * 1e-9 * eth_price)

fig.text(0.5, 0.02,
         f'Total Deployment: {int(total_gas):,} gas = ${cost_usd:.2f} at Base L2 (0.15 Gwei, ETH=$2500)',
         ha='center', fontsize=10, fontweight='bold',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgreen', alpha=0.8, edgecolor='darkgreen', linewidth=2))

plt.tight_layout(rect=[0, 0.05, 1, 1])
plt.savefig('deployment_waterfall.pdf', dpi=300, bbox_inches='tight')
plt.savefig('deployment_waterfall.png', dpi=300, bbox_inches='tight')
print("✓ Generated: deployment_waterfall.pdf/png")
plt.close()
