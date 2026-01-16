#!/usr/bin/env python3
"""
EVMAuth Composability Stack
Layer cake diagram showing how EVMAuth integrates into the blockchain ecosystem
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 10

fig, ax = plt.subplots(figsize=(14, 10))
ax.set_xlim(0, 14)
ax.set_ylim(0, 12)
ax.axis('off')

# Layer specifications: (y_position, height, color, title, components)
layers = [
    # Layer 1: Consensus (bottom)
    {
        'y': 1,
        'height': 1.5,
        'color': '#E8E8E8',
        'title': 'Layer 1: Consensus & Network',
        'components': [
            'Ethereum Mainnet',
            'Base L2',
            'Arbitrum L2',
            'Optimism L2',
            'Any EVM Chain'
        ],
        'description': 'EVMAuth is chain-agnostic: deploy on any EVM-compatible network'
    },
    # Layer 2: Blockchain primitives
    {
        'y': 2.5,
        'height': 1.5,
        'color': '#D4E6F1',
        'title': 'Layer 2: Blockchain Primitives',
        'components': [
            'EVM Runtime',
            'State Storage',
            'Transaction Processing',
            'Event Logs',
            'EIP-7201 Namespaced Storage'
        ],
        'description': 'Core blockchain capabilities: immutable state, cryptographic verification'
    },
    # Layer 3: Token standards
    {
        'y': 4,
        'height': 1.5,
        'color': '#FCF3CF',
        'title': 'Layer 3: Token Standards',
        'components': [
            'ERC-1155',
            'ERC-6909',
            'ERC-20 (Payment)',
            'ERC-165 (Interfaces)',
            'AccessControl'
        ],
        'description': 'Standard interfaces enabling interoperability with wallets, explorers, DEXs'
    },
    # Layer 4: EVMAuth (the focus)
    {
        'y': 5.5,
        'height': 2,
        'color': '#A9DFBF',
        'title': 'Layer 4: EVMAuth Authorization Layer',
        'components': [
            'Ephemeral Tokens',
            'Role-Based Types',
            'Multi-Currency Pricing',
            'Transferable/Soulbound',
            'Account Freezing',
            'Pausable Operations',
            'UUPS Upgradeable'
        ],
        'description': 'Authorization-as-asset primitives: composable, interoperable, self-sovereign'
    },
    # Layer 5: Applications
    {
        'y': 7.5,
        'height': 3.5,
        'color': '#F9E79F',
        'title': 'Layer 5: Applications & Integrations',
        'components': [],  # Will be drawn separately as grid
        'description': 'EVMAuth enables diverse use cases through composable authorization',
        'use_cases': [
            ('SaaS Gating', 'Pay-per-use APIs with token ownership'),
            ('AI Agent Auth', 'Autonomous agents own access credentials'),
            ('DeFi Access Control', 'Token-gated vaults and strategies'),
            ('Gaming/NFT Utilities', 'Transferable in-game subscriptions'),
            ('DAO Governance', 'Role-based proposal/voting rights'),
            ('Enterprise RBAC', 'Compliant access with freezing'),
            ('Education Platforms', 'Student licenses with expiration'),
            ('Content Platforms', 'Creator subscriptions on-chain'),
            ('IoT/Edge Devices', 'Device credentials as tokens'),
            ('Healthcare Systems', 'HIPAA-compliant role tokens'),
            ('Supply Chain', 'Verifiable access credentials'),
            ('Identity Systems', 'Composable identity attributes')
        ]
    }
]

# Draw layers bottom-up
for i, layer in enumerate(layers):
    y = layer['y']
    height = layer['height']
    color = layer['color']

    # Main layer box
    if i == 3:  # EVMAuth layer - make it stand out
        box = FancyBboxPatch((1, y), 12, height,
                            boxstyle="round,pad=0.1",
                            edgecolor='darkgreen', facecolor=color,
                            linewidth=4, zorder=2)
    else:
        box = Rectangle((1, y), 12, height,
                       edgecolor='black', facecolor=color,
                       linewidth=2, zorder=1)
    ax.add_patch(box)

    # Layer title
    ax.text(7, y + height - 0.2, layer['title'],
            ha='center', va='top', fontsize=11,
            fontweight='bold', zorder=3)

    # Layer description
    ax.text(7, y + height - 0.5, layer['description'],
            ha='center', va='top', fontsize=8,
            style='italic', zorder=3)

    # Components
    if i < 4:  # Not the application layer
        # Horizontal list of components
        num_components = len(layer['components'])
        component_width = 10 / num_components
        for j, component in enumerate(layer['components']):
            x_pos = 2 + j * component_width
            y_pos = y + 0.3
            ax.text(x_pos + component_width/2, y_pos, component,
                    ha='center', va='center', fontsize=7,
                    bbox=dict(boxstyle='round,pad=0.2', facecolor='white',
                             edgecolor='gray', linewidth=1),
                    zorder=4)
    else:
        # Application layer - grid of use cases
        use_cases = layer['use_cases']
        rows = 3
        cols = 4
        box_width = 2.6
        box_height = 0.6
        start_x = 1.8
        start_y = y + 0.2

        for idx, (title, desc) in enumerate(use_cases):
            row = idx // cols
            col = idx % cols
            x_pos = start_x + col * (box_width + 0.2)
            y_pos = start_y + (rows - 1 - row) * (box_height + 0.3)

            # Use case box
            case_box = FancyBboxPatch((x_pos, y_pos), box_width, box_height,
                                     boxstyle="round,pad=0.05",
                                     edgecolor='darkorange', facecolor='#FFF9E6',
                                     linewidth=1.5, zorder=4)
            ax.add_patch(case_box)

            # Title
            ax.text(x_pos + box_width/2, y_pos + box_height - 0.15,
                    title, ha='center', va='top', fontsize=7,
                    fontweight='bold', zorder=5)

            # Description
            ax.text(x_pos + box_width/2, y_pos + 0.15,
                    desc, ha='center', va='bottom', fontsize=6,
                    zorder=5, wrap=True)

# Add connecting arrows showing data flow
arrow_props = dict(arrowstyle='->', lw=3, color='#2E86AB')

# Consensus → Blockchain
ax.annotate('', xy=(7, 4), xytext=(7, 2.5),
            arrowprops=arrow_props)

# Blockchain → Standards
ax.annotate('', xy=(7, 5.5), xytext=(7, 4),
            arrowprops=arrow_props)

# Standards → EVMAuth
ax.annotate('', xy=(7, 7.5), xytext=(7, 5.5),
            arrowprops=arrow_props)

# EVMAuth → Applications
ax.annotate('', xy=(7, 11), xytext=(7, 7.5),
            arrowprops=arrow_props)

# Add side annotations
ax.text(0.5, 6.5, 'Builds\nOn', rotation=90, ha='center', va='center',
        fontsize=10, fontweight='bold', color='#2E86AB')

ax.text(13.5, 6.5, 'Enables\nComposability', rotation=90, ha='center', va='center',
        fontsize=10, fontweight='bold', color='#6A994E')

# Title
ax.text(7, 11.5, 'EVMAuth Composability Stack',
        ha='center', fontsize=14, fontweight='bold')

# Legend for Layer 4
legend_y = 0.3
ax.text(7, legend_y, 'EVMAuth Layer (Green): Seven composable primitives enable diverse applications',
        ha='center', fontsize=9, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='lightgreen',
                 edgecolor='darkgreen', linewidth=2))

plt.tight_layout()
plt.savefig('composability_stack.pdf', dpi=300, bbox_inches='tight')
plt.savefig('composability_stack.png', dpi=300, bbox_inches='tight')
print("✓ Generated: composability_stack.pdf/png")
plt.close()
