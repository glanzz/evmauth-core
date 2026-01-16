#!/usr/bin/env python3
"""
Total Cost of Ownership (TCO) Line Chart
Compares EVMAuth vs OAuth monthly costs at different user scales
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

# User scale (logarithmic)
users = np.array([100, 1000, 10000, 100000])

# EVMAuth costs
# Infrastructure: $5-30/month (using $17.5 average)
# Per-user gas cost: $0.00037 (one-time purchase on Layer 2)
# Monthly operational cost is just infrastructure (gas is one-time)
evmauth_min = np.array([5, 5, 5, 5])  # Min infrastructure
evmauth_max = np.array([30, 30, 30, 30])  # Max infrastructure
evmauth_avg = (evmauth_min + evmauth_max) / 2

# OAuth costs
# Infrastructure: $55-160/month
# No per-user gas cost, but scales with database/cache needs
# Assume infrastructure scales slightly with user count
oauth_base_min = 55
oauth_base_max = 160
oauth_min = np.array([55, 60, 70, 90])  # Slight scaling for DB/cache
oauth_max = np.array([160, 175, 200, 250])  # More significant scaling at high volume
oauth_avg = (oauth_min + oauth_max) / 2

fig, ax = plt.subplots(figsize=(10, 6))

# Plot EVMAuth range (shaded area)
ax.fill_between(users, evmauth_min, evmauth_max, alpha=0.3, color='#2E86AB', label='EVMAuth range')
ax.plot(users, evmauth_avg, 'o-', color='#2E86AB', linewidth=2.5, markersize=8,
        label='EVMAuth (avg)', markeredgecolor='black', markeredgewidth=1)

# Plot OAuth range (shaded area)
ax.fill_between(users, oauth_min, oauth_max, alpha=0.3, color='#A23B72', label='OAuth range')
ax.plot(users, oauth_avg, 's-', color='#A23B72', linewidth=2.5, markersize=8,
        label='OAuth (avg)', markeredgecolor='black', markeredgewidth=1)

# Set logarithmic x-axis
ax.set_xscale('log')
ax.set_xlabel('Number of Users (log scale)', fontweight='bold')
ax.set_ylabel('Monthly Cost (USD)', fontweight='bold')
ax.set_title('Total Cost of Ownership: EVMAuth vs OAuth', fontweight='bold', pad=15)

# Format x-axis ticks
ax.set_xticks(users)
ax.set_xticklabels(['100', '1K', '10K', '100K'])

# Grid
ax.grid(True, which='both', alpha=0.3, linestyle='--', linewidth=0.5)

# Legend
ax.legend(loc='upper left', frameon=True, fancybox=False, edgecolor='black')

# Add value annotations for key points
for i, u in enumerate(users):
    # EVMAuth avg annotation
    ax.annotate(f'${evmauth_avg[i]:.0f}',
                xy=(u, evmauth_avg[i]),
                xytext=(0, 10),
                textcoords='offset points',
                ha='center', fontsize=8,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='lightblue', alpha=0.7, edgecolor='none'))

    # OAuth avg annotation
    ax.annotate(f'${oauth_avg[i]:.0f}',
                xy=(u, oauth_avg[i]),
                xytext=(0, -15),
                textcoords='offset points',
                ha='center', fontsize=8,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='lightpink', alpha=0.7, edgecolor='none'))

# Add cost savings annotation
ax.annotate('EVMAuth cheaper at all scales',
            xy=(10000, 17.5), xytext=(30000, 100),
            arrowprops=dict(arrowstyle='->', lw=1.5, color='green'),
            fontsize=10, color='green', ha='center', fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgreen', alpha=0.5, edgecolor='darkgreen'))

# Add note about stateless architecture
fig.text(0.5, 0.02,
         'Note: EVMAuth costs remain flat due to stateless architecture. Gas costs are one-time ($0.00037/user on L2).',
         ha='center', fontsize=9, style='italic',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightyellow', edgecolor='black'))

plt.tight_layout(rect=[0, 0.06, 1, 1])
plt.savefig('tco_line_chart.pdf', dpi=300, bbox_inches='tight')
plt.savefig('tco_line_chart.png', dpi=300, bbox_inches='tight')
print("✓ Generated: tco_line_chart.pdf/png")
plt.close()
