#!/usr/bin/env python3
"""
Multi-Currency Pricing Model
Network diagram showing how one token type accepts multiple currencies
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Circle, FancyArrowPatch, FancyBboxPatch
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10

fig, ax = plt.subplots(figsize=(12, 10))
ax.set_xlim(-1.5, 1.5)
ax.set_ylim(-1.5, 1.8)
ax.set_aspect('equal')
ax.axis('off')

# Center: Token Type
center_x, center_y = 0, 0
center_radius = 0.25

# Draw center token
center = Circle((center_x, center_y), center_radius, color='#2E86AB',
                edgecolor='black', linewidth=3, zorder=10)
ax.add_patch(center)
ax.text(center_x, center_y, 'Premium\nToken\n(ID: 1)',
        ha='center', va='center', fontsize=11, fontweight='bold',
        color='white', zorder=11)

# Currency positions (8 points around circle)
currencies = [
    {'name': 'ETH', 'symbol': 'Ξ', 'price': '0.005 ETH', 'color': '#627EEA', 'angle': 0},
    {'name': 'USDC', 'symbol': '$', 'price': '$5.00', 'color': '#2775CA', 'angle': np.pi/4},
    {'name': 'DAI', 'symbol': '◈', 'price': '$5.00', 'color': '#F5AC37', 'angle': np.pi/2},
    {'name': 'WETH', 'symbol': 'W', 'price': '0.005 WETH', 'color': '#C1AAF5', 'angle': 3*np.pi/4},
    {'name': 'USDT', 'symbol': '₮', 'price': '$5.00', 'color': '#26A17B', 'angle': np.pi},
    {'name': 'WBTC', 'symbol': '₿', 'price': '0.00013 WBTC', 'color': '#F7931A', 'angle': 5*np.pi/4},
    {'name': 'ARB', 'symbol': '🔷', 'price': '5.5 ARB', 'color': '#2C374B', 'angle': 3*np.pi/2},
    {'name': 'OP', 'symbol': '⚡', 'price': '2.8 OP', 'color': '#FF0420', 'angle': 7*np.pi/4},
]

radius_distance = 0.9
currency_radius = 0.15

# Draw currencies and connections
for curr in currencies:
    # Calculate position
    x = center_x + radius_distance * np.cos(curr['angle'])
    y = center_y + radius_distance * np.sin(curr['angle'])

    # Draw currency circle
    circ = Circle((x, y), currency_radius, color=curr['color'],
                  edgecolor='black', linewidth=2, alpha=0.8, zorder=5)
    ax.add_patch(circ)

    # Currency symbol (large)
    ax.text(x, y + 0.03, curr['symbol'],
            ha='center', va='center', fontsize=20, fontweight='bold',
            color='white', zorder=6)

    # Currency name
    ax.text(x, y - 0.06, curr['name'],
            ha='center', va='center', fontsize=8, fontweight='bold',
            color='white', zorder=6)

    # Draw arrow from currency to center
    arrow = FancyArrowPatch(
        (x - currency_radius * 0.7 * np.cos(curr['angle']),
         y - currency_radius * 0.7 * np.sin(curr['angle'])),
        (center_x + center_radius * np.cos(curr['angle']),
         center_y + center_radius * np.sin(curr['angle'])),
        arrowstyle='-|>',
        mutation_scale=25,
        linewidth=2.5,
        color=curr['color'],
        alpha=0.6,
        zorder=1
    )
    ax.add_patch(arrow)

    # Price label along the arrow
    mid_x = (x + center_x) / 2
    mid_y = (y + center_y) / 2
    ax.text(mid_x, mid_y, curr['price'],
            ha='center', va='bottom', fontsize=8,
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white',
                     edgecolor=curr['color'], linewidth=1.5, alpha=0.9),
            zorder=7)

# Add title
ax.text(0, 1.5, 'Multi-Currency Pricing Model',
        ha='center', fontsize=14, fontweight='bold')

ax.text(0, 1.35, 'One Token Type, Multiple Payment Options',
        ha='center', fontsize=11, style='italic', color='#555555')

# Add legend explaining the diagram
legend_y = -1.2
ax.text(-1.4, legend_y, 'Key Features:', fontsize=10, fontweight='bold')
ax.text(-1.4, legend_y - 0.15, '• Independent pricing per currency', fontsize=9)
ax.text(-1.4, legend_y - 0.30, '• User chooses payment method', fontsize=9)
ax.text(-1.4, legend_y - 0.45, '• Treasury receives exact amount', fontsize=9)

ax.text(0.3, legend_y, 'Benefits:', fontsize=10, fontweight='bold')
ax.text(0.3, legend_y - 0.15, '• No price oracles needed', fontsize=9)
ax.text(0.3, legend_y - 0.30, '• Eliminates slippage risk', fontsize=9)
ax.text(0.3, legend_y - 0.45, '• Flexible for global users', fontsize=9)

# Add example purchase flow
example_box = FancyBboxPatch((-0.55, -1.0), 1.1, 0.35,
                             boxstyle="round,pad=0.05",
                             edgecolor='#6A994E', facecolor='#E8F5E9',
                             linewidth=2, zorder=3)
ax.add_patch(example_box)

ax.text(0, -0.7, 'Example Purchase:', fontsize=9, fontweight='bold', ha='center')
ax.text(0, -0.83, 'user.purchase{value: 0.005 ETH}(tokenId: 1, quantity: 1)',
        ha='center', fontsize=8, family='monospace',
        bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='black'))

# Add contract storage representation
storage_y = -1.35
ax.text(0, storage_y - 0.05, 'Contract Storage (per token type):',
        ha='center', fontsize=9, fontweight='bold')

storage_items = [
    'tokenPrice[1] = 5000000000000000 // 0.005 ETH',
    'erc20Prices[1][USDC] = 5000000 // $5.00 (6 decimals)',
    'erc20Prices[1][DAI] = 5000000000000000000 // $5.00 (18 decimals)',
]

for i, item in enumerate(storage_items):
    ax.text(0, storage_y - 0.20 - i*0.12, item,
            ha='center', fontsize=7, family='monospace',
            color='#333333')

plt.tight_layout()
plt.savefig('multi_currency_pricing.pdf', dpi=300, bbox_inches='tight')
plt.savefig('multi_currency_pricing.png', dpi=300, bbox_inches='tight')
print("✓ Generated: multi_currency_pricing.pdf/png")
plt.close()
