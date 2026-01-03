#!/usr/bin/env python3
"""
Deployment Cost Breakdown: Stacked Bar Chart
Shows ERC-1155 vs ERC-6909 deployment costs broken down by components
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

# Data from gas reports (in gas units)
# ERC-1155: Total 8,212,855 gas
# ERC-6909: Total 7,571,932 gas
# Breakdown (from deployment logs):
# - Proxy deployment: ~205K gas (ERC1967Proxy)
# - Implementation: ERC-1155: 5,355,027 gas, ERC-6909: 4,864,022 gas
# - Token configuration (5 tokens): ~2.65M gas for 1155, ~2.5M gas for 6909

implementations = ['ERC-1155', 'ERC-6909']

# Gas costs in thousands
proxy_costs = [205, 205]  # Same for both
implementation_costs = [5355, 4864]  # Contract deployment
config_costs = [2653, 2503]  # 5 token configurations

# Calculate totals
totals = [sum(x) for x in zip(proxy_costs, implementation_costs, config_costs)]

x = np.arange(len(implementations))
width = 0.5

fig, ax = plt.subplots(figsize=(8, 6))

# Create stacked bars
p1 = ax.bar(x, proxy_costs, width, label='Proxy Deployment',
            color='#6A994E', edgecolor='black', linewidth=1)
p2 = ax.bar(x, implementation_costs, width, bottom=proxy_costs,
            label='Implementation Contract', color='#2E86AB', edgecolor='black', linewidth=1)
p3 = ax.bar(x, config_costs, width,
            bottom=[i+j for i,j in zip(proxy_costs, implementation_costs)],
            label='Token Configuration (5 tokens)', color='#F18F01', edgecolor='black', linewidth=1)

ax.set_ylabel('Gas Cost (thousands)', fontweight='bold')
ax.set_title('EVMAuth Deployment Cost Breakdown', fontweight='bold', pad=15)
ax.set_xticks(x)
ax.set_xticklabels(implementations)
ax.legend(loc='upper right', frameon=True, fancybox=False, edgecolor='black')
ax.grid(True, axis='y', alpha=0.3, linestyle='--', linewidth=0.5)

# Add value labels on each segment
for i, impl in enumerate(implementations):
    # Proxy label
    ax.text(i, proxy_costs[i]/2, f'{proxy_costs[i]}K',
            ha='center', va='center', fontweight='bold', fontsize=9, color='white')

    # Implementation label
    y_pos = proxy_costs[i] + implementation_costs[i]/2
    ax.text(i, y_pos, f'{implementation_costs[i]}K',
            ha='center', va='center', fontweight='bold', fontsize=9, color='white')

    # Config label
    y_pos = proxy_costs[i] + implementation_costs[i] + config_costs[i]/2
    ax.text(i, y_pos, f'{config_costs[i]}K',
            ha='center', va='center', fontweight='bold', fontsize=9, color='white')

    # Total label above bar
    ax.text(i, totals[i] + 200, f'Total:\n{totals[i]}K gas',
            ha='center', va='bottom', fontweight='bold', fontsize=10,
            bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', edgecolor='black'))

# Add cost comparison at Base L2 (0.15 Gwei, ETH=$2500)
eth_price = 2500
gas_price_gwei = 0.15
cost_1155 = (8212855 * gas_price_gwei * 1e-9 * eth_price)
cost_6909 = (7571932 * gas_price_gwei * 1e-9 * eth_price)

fig.text(0.5, 0.02,
         f'At Base L2 (0.15 Gwei, ETH=$2500): ERC-1155 = ${cost_1155:.2f}, ERC-6909 = ${cost_6909:.2f} | Savings: {((cost_1155-cost_6909)/cost_1155*100):.1f}%',
         ha='center', fontsize=9, style='italic',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgreen', alpha=0.7, edgecolor='darkgreen'))

plt.tight_layout(rect=[0, 0.06, 1, 1])
plt.savefig('deployment_stacked_bar.pdf', dpi=300, bbox_inches='tight')
plt.savefig('deployment_stacked_bar.png', dpi=300, bbox_inches='tight')
print("✓ Generated: deployment_stacked_bar.pdf/png")
plt.close()
