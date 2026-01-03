#!/usr/bin/env python3
"""
Infrastructure Cost Breakdown: Dual Pie Charts
Compares EVMAuth vs OAuth infrastructure component costs
"""

import matplotlib.pyplot as plt
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10
plt.rcParams['legend.fontsize'] = 9

# Data from paper (Section 5.4)
# EVMAuth: RPC ($0-25) + Server ($5) = $5-30/month
# OAuth: Auth service ($25-100) + DB ($15-30) + Redis ($10-25) + Server ($5) = $55-160/month

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

# EVMAuth infrastructure (using mid-range values)
evmauth_components = ['RPC\n$0-25', 'API Server\n$5']
evmauth_costs = [12.5, 5]  # Mid-range values
evmauth_colors = ['#2E86AB', '#A6CEE3']

wedges1, texts1, autotexts1 = ax1.pie(evmauth_costs, labels=evmauth_components,
                                        autopct='%1.1f%%', startangle=90,
                                        colors=evmauth_colors,
                                        wedgeprops=dict(edgecolor='black', linewidth=1.5))
ax1.set_title('EVMAuth Infrastructure\nTotal: $5-30/month', fontweight='bold', fontsize=12, pad=15)

# Make percentage text bold
for autotext in autotexts1:
    autotext.set_color('white')
    autotext.set_fontweight('bold')
    autotext.set_fontsize(10)

# OAuth infrastructure (using mid-range values)
oauth_components = ['Auth Service\n$25-100', 'PostgreSQL\n$15-30', 'Redis Cache\n$10-25', 'API Server\n$5']
oauth_costs = [62.5, 22.5, 17.5, 5]  # Mid-range values
oauth_colors = ['#A23B72', '#F18F01', '#C73E1D', '#6A994E']

wedges2, texts2, autotexts2 = ax2.pie(oauth_costs, labels=oauth_components,
                                        autopct='%1.1f%%', startangle=90,
                                        colors=oauth_colors,
                                        wedgeprops=dict(edgecolor='black', linewidth=1.5))
ax2.set_title('OAuth Infrastructure\nTotal: $55-160/month', fontweight='bold', fontsize=12, pad=15)

# Make percentage text bold
for autotext in autotexts2:
    autotext.set_color('white')
    autotext.set_fontweight('bold')
    autotext.set_fontsize(10)

# Add overall comparison annotation
fig.suptitle('Monthly Infrastructure Costs Comparison (100K API requests)',
             fontweight='bold', fontsize=14, y=1.00)

# Add cost savings annotation
fig.text(0.5, 0.02, 'EVMAuth: 2 services vs OAuth: 4 services | Cost reduction: up to 87%',
         ha='center', fontsize=10, style='italic',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightyellow', edgecolor='black'))

plt.tight_layout(rect=[0, 0.05, 1, 0.96])
plt.savefig('infrastructure_cost_pie.pdf', dpi=300, bbox_inches='tight')
plt.savefig('infrastructure_cost_pie.png', dpi=300, bbox_inches='tight')
print("✓ Generated: infrastructure_cost_pie.pdf/png")
plt.close()
