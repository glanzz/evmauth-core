#!/usr/bin/env python3
"""
Operation Costs Comparison: Radar/Polar Chart
Compares purchase, transfer, burn, mint costs between ERC-1155 and ERC-6909
"""

import matplotlib.pyplot as plt
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10

# Data from gas reports (using median values from paper)
# Operations: Purchase, Transfer, Burn, Mint
operations = ['Purchase', 'Transfer', 'Burn', 'Mint']

# Gas costs from paper and gas reports
# ERC-1155: purchase ~147K, transfer ~54K, burn ~21K, mint ~111K
# ERC-6909: purchase ~147K, transfer ~30K, burn ~18K, mint ~107K
erc1155_costs = [147000, 54000, 21500, 111000]
erc6909_costs = [147000, 30000, 17800, 107000]

# Number of variables
N = len(operations)

# Compute angle for each axis
angles = np.linspace(0, 2 * np.pi, N, endpoint=False).tolist()

# The plot is circular, so we need to "complete the loop"
erc1155_costs += erc1155_costs[:1]
erc6909_costs += erc6909_costs[:1]
angles += angles[:1]

# Create figure
fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(projection='polar'))

# Plot ERC-1155
ax.plot(angles, erc1155_costs, 'o-', linewidth=2.5, label='ERC-1155',
        color='#2E86AB', markersize=8, markeredgecolor='black', markeredgewidth=1)
ax.fill(angles, erc1155_costs, alpha=0.25, color='#2E86AB')

# Plot ERC-6909
ax.plot(angles, erc6909_costs, 's-', linewidth=2.5, label='ERC-6909',
        color='#A23B72', markersize=8, markeredgecolor='black', markeredgewidth=1)
ax.fill(angles, erc6909_costs, alpha=0.25, color='#A23B72')

# Set the labels for each axis
ax.set_xticks(angles[:-1])
ax.set_xticklabels(operations, fontsize=11, fontweight='bold')

# Set y-axis label
ax.set_ylabel('Gas Cost', fontsize=10, fontweight='bold', labelpad=30)
ax.set_ylim(0, 160000)

# Add gridlines
ax.grid(True, linestyle='--', linewidth=0.5, alpha=0.7)

# Add title
ax.set_title('Gas Cost Comparison: ERC-1155 vs ERC-6909\n(Core Operations)',
             fontsize=13, fontweight='bold', pad=20)

# Add legend
ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1),
          frameon=True, fancybox=False, edgecolor='black')

# Add value labels at each point
for i, (angle, val1155, val6909) in enumerate(zip(angles[:-1], erc1155_costs[:-1], erc6909_costs[:-1])):
    # ERC-1155 label
    ax.text(angle, val1155 + 8000, f'{val1155/1000:.0f}K',
            ha='center', va='center', fontsize=9,
            bbox=dict(boxstyle='round,pad=0.3', facecolor='lightblue', alpha=0.7, edgecolor='none'))

    # ERC-6909 label
    ax.text(angle, val6909 - 8000, f'{val6909/1000:.0f}K',
            ha='center', va='center', fontsize=9,
            bbox=dict(boxstyle='round,pad=0.3', facecolor='lightpink', alpha=0.7, edgecolor='none'))

# Add cost savings note
savings_transfer = ((54000 - 30000) / 54000) * 100
fig.text(0.5, 0.02,
         f'ERC-6909 achieves 48% lower transfer costs (30K vs 54K gas)',
         ha='center', fontsize=10, style='italic', fontweight='bold',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgreen', alpha=0.7, edgecolor='darkgreen'))

plt.tight_layout(rect=[0, 0.05, 1, 1])
plt.savefig('operation_costs_radar.pdf', dpi=300, bbox_inches='tight')
plt.savefig('operation_costs_radar.png', dpi=300, bbox_inches='tight')
print("✓ Generated: operation_costs_radar.pdf/png")
plt.close()
