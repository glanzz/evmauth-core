#!/usr/bin/env python3
"""
Seven Authorization Primitives Wheel
Radial diagram showing EVMAuth's seven composable primitives
"""

import matplotlib.pyplot as plt
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10

# Seven primitives with key metrics
primitives = [
    'Ephemeral\nTokens',
    'Role-Based\nTypes',
    'Multi-\nCurrency',
    'Transferable/\nSoulbound',
    'Account\nFreezing',
    'Pausable\nOps',
    'Upgradeable\n(UUPS)'
]

metrics = [
    '148K gas\nconstant',
    'Unlimited\ntiers',
    'ETH +\nERC-20',
    'Per-token\nconfig',
    'Instant\nrevoke',
    'Circuit\nbreaker',
    'EIP-7201\nstorage'
]

# Colors for each primitive (rainbow-like gradient)
colors = ['#2E86AB', '#A23B72', '#F18F01', '#6A994E', '#C73E1D', '#9B59B6', '#1ABC9C']

# Create figure
fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))

# Number of primitives
N = len(primitives)
angles = np.linspace(0, 2 * np.pi, N, endpoint=False).tolist()

# Make the plot circular by appending the first value
angles += angles[:1]

# Plot data (all at same radius for wheel effect)
radius = [1] * N
radius += radius[:1]

# Draw the wheel segments
for i in range(N):
    # Create wedge for each primitive
    theta1 = angles[i]
    theta2 = angles[i + 1]

    # Draw filled wedge
    theta = np.linspace(theta1, theta2, 100)
    r = np.ones(100)
    ax.fill_between(theta, 0, r, alpha=0.3, color=colors[i])
    ax.plot([theta1, theta1], [0, 1], 'k-', linewidth=2)

# Draw center circle
center_circle = plt.Circle((0, 0), 0.3, color='white', fill=True, zorder=10,
                           edgecolor='black', linewidth=2)
ax.add_patch(center_circle)

# Add center text
ax.text(0, 0, 'EVMAuth\nCore', ha='center', va='center', fontsize=14,
        fontweight='bold', zorder=11)

# Add primitive labels
for i, (angle, primitive, metric, color) in enumerate(zip(angles[:-1], primitives, metrics, colors)):
    # Primitive name (outer ring)
    ax.text(angle, 1.25, primitive, ha='center', va='center',
            fontsize=10, fontweight='bold', color=color,
            bbox=dict(boxstyle='round,pad=0.5', facecolor='white', edgecolor=color, linewidth=2))

    # Metric (inner ring)
    ax.text(angle, 0.65, metric, ha='center', va='center',
            fontsize=8, style='italic',
            bbox=dict(boxstyle='round,pad=0.3', facecolor=color, edgecolor='black', alpha=0.3))

# Customize plot
ax.set_ylim(0, 1.5)
ax.set_yticks([])
ax.set_xticks([])
ax.spines['polar'].set_visible(False)
ax.grid(False)

# Add title
plt.title('EVMAuth: Seven Orthogonal Authorization Primitives',
          fontsize=14, fontweight='bold', pad=30)

# Add note
fig.text(0.5, 0.02,
         'All primitives work together within standard ERC-1155/6909 interfaces',
         ha='center', fontsize=9, style='italic',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightyellow', edgecolor='black'))

plt.tight_layout(rect=[0, 0.05, 1, 1])
plt.savefig('seven_primitives_wheel.pdf', dpi=300, bbox_inches='tight')
plt.savefig('seven_primitives_wheel.png', dpi=300, bbox_inches='tight')
print("✓ Generated: seven_primitives_wheel.pdf/png")
plt.close()
