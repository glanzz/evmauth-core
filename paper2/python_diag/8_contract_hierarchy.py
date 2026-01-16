#!/usr/bin/env python3
"""
Smart Contract Inheritance Hierarchy
Tree diagram showing EVMAuth contract architecture
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 9

fig, ax = plt.subplots(figsize=(14, 10))
ax.set_xlim(0, 14)
ax.set_ylim(0, 10)
ax.axis('off')

# Color scheme
color_openzeppelin = '#E8F4F8'  # Light blue for OpenZeppelin
color_base = '#FFE5CC'  # Light orange for base modules
color_evmauth = '#D4EDDA'  # Light green for EVMAuth core
color_implementation = '#FFF3CD'  # Light yellow for implementations

def draw_box(ax, x, y, width, height, text, color, fontsize=9, bold=False):
    """Draw a fancy box with text"""
    box = FancyBboxPatch((x, y), width, height,
                         boxstyle="round,pad=0.1",
                         edgecolor='black', facecolor=color,
                         linewidth=1.5, zorder=1)
    ax.add_patch(box)

    weight = 'bold' if bold else 'normal'
    ax.text(x + width/2, y + height/2, text,
            ha='center', va='center', fontsize=fontsize,
            fontweight=weight, zorder=2)
    return (x + width/2, y)

def draw_arrow(ax, x1, y1, x2, y2, style='solid'):
    """Draw inheritance arrow"""
    arrow = FancyArrowPatch((x1, y1), (x2, y2),
                           arrowstyle='-|>',
                           mutation_scale=20,
                           linewidth=2 if style=='solid' else 1.5,
                           linestyle=style,
                           color='black',
                           zorder=0)
    ax.add_patch(arrow)

# Layer 1: OpenZeppelin Base (Top)
y_oz = 9
oz_uups = draw_box(ax, 1, y_oz, 2, 0.6, 'UUPS\nUpgradeable', color_openzeppelin, 8)
oz_access = draw_box(ax, 4, y_oz, 2, 0.6, 'Access\nControl', color_openzeppelin, 8)
oz_pausable = draw_box(ax, 7, y_oz, 2, 0.6, 'Pausable', color_openzeppelin, 8)
oz_1155 = draw_box(ax, 10, y_oz, 2, 0.6, 'ERC1155\nUpgradeable', color_openzeppelin, 8)
oz_init = draw_box(ax, 12.5, y_oz, 1.2, 0.6, 'Initializable', color_openzeppelin, 7)

# Layer 2: Base Modules (Middle-Upper)
y_base = 7
base_ephemeral = draw_box(ax, 0.5, y_base, 2.2, 0.6, 'TokenEphemeral', color_base, 9, True)
base_purchasable = draw_box(ax, 3, y_base, 2.2, 0.6, 'TokenPurchasable', color_base, 9, True)
base_freezable = draw_box(ax, 5.5, y_base, 2.2, 0.6, 'AccountFreezable', color_base, 9, True)
base_transferable = draw_box(ax, 8, y_base, 2.2, 0.6, 'TokenTransferable', color_base, 9, True)
base_enumerable = draw_box(ax, 10.5, y_base, 2.2, 0.6, 'TokenEnumerable', color_base, 9, True)

# Arrows from OpenZeppelin to Base modules
draw_arrow(ax, oz_uups[0], oz_uups[1], base_ephemeral[0], base_ephemeral[1] + 0.6)
draw_arrow(ax, oz_access[0], oz_access[1], base_freezable[0], base_freezable[1] + 0.6)
draw_arrow(ax, oz_pausable[0], oz_pausable[1], base_purchasable[0], base_purchasable[1] + 0.6)
draw_arrow(ax, oz_init[0], oz_init[1], base_enumerable[0], base_enumerable[1] + 0.6)

# Layer 3: EVMAuth Core (Middle)
y_core = 5
core_access = draw_box(ax, 2, y_core, 2.5, 0.6, 'TokenAccessControl', color_evmauth, 9, True)
core_evmauth = draw_box(ax, 5.5, y_core, 2, 0.7, 'EVMAuth\n(Base)', color_evmauth, 10, True)

# Arrows from Base modules to Core
draw_arrow(ax, base_ephemeral[0], base_ephemeral[1], core_evmauth[0] - 0.5, core_evmauth[1] + 0.7)
draw_arrow(ax, base_purchasable[0], base_purchasable[1], core_evmauth[0], core_evmauth[1] + 0.7)
draw_arrow(ax, base_freezable[0], base_freezable[1], core_access[0], core_access[1] + 0.6)
draw_arrow(ax, base_transferable[0], base_transferable[1], core_evmauth[0] + 0.5, core_evmauth[1] + 0.7)
draw_arrow(ax, base_enumerable[0], base_enumerable[1], core_evmauth[0] + 0.8, core_evmauth[1] + 0.7)

# Arrow from TokenAccessControl to EVMAuth
draw_arrow(ax, core_access[0] + 1, core_access[1], core_evmauth[0] - 0.8, core_evmauth[1] + 0.35)

# Layer 4: Implementations (Bottom)
y_impl = 2.5
impl_1155 = draw_box(ax, 3, y_impl, 2.5, 0.8, 'EVMAuth1155\n(24.6 KB)', color_implementation, 10, True)
impl_6909 = draw_box(ax, 7, y_impl, 2.5, 0.8, 'EVMAuth6909\n(22.3 KB)', color_implementation, 10, True)

# Arrows from Core to Implementations
draw_arrow(ax, core_evmauth[0] - 0.5, core_evmauth[1], impl_1155[0], impl_1155[1] + 0.8)
draw_arrow(ax, core_evmauth[0] + 0.5, core_evmauth[1], impl_6909[0], impl_6909[1] + 0.8)

# Arrow from ERC1155 to EVMAuth1155
draw_arrow(ax, oz_1155[0], oz_1155[1], impl_1155[0] + 1, impl_1155[1] + 0.8, style='dashed')

# Add annotations for module types
ax.text(0.3, 8.2, 'OpenZeppelin', fontsize=10, fontweight='bold', color='#0066CC')
ax.text(0.3, 6.2, 'Base Modules', fontsize=10, fontweight='bold', color='#FF8800')
ax.text(0.3, 4.3, 'Core Logic', fontsize=10, fontweight='bold', color='#00AA00')
ax.text(0.3, 1.7, 'Implementations', fontsize=10, fontweight='bold', color='#CCAA00')

# Add legend for module categories
legend_elements = [
    mpatches.Rectangle((0, 0), 1, 1, fc=color_openzeppelin, ec='black', lw=1.5, label='OpenZeppelin (Audited)'),
    mpatches.Rectangle((0, 0), 1, 1, fc=color_base, ec='black', lw=1.5, label='Custom Modules'),
    mpatches.Rectangle((0, 0), 1, 1, fc=color_evmauth, ec='black', lw=1.5, label='EVMAuth Core'),
    mpatches.Rectangle((0, 0), 1, 1, fc=color_implementation, ec='black', lw=1.5, label='Final Implementations'),
]
ax.legend(handles=legend_elements, loc='lower right', fontsize=9, frameon=True,
          fancybox=False, edgecolor='black')

# Add module descriptions
descriptions = [
    (base_ephemeral[0], y_base - 0.3, 'Time-bounded\nexpiration'),
    (base_purchasable[0], y_base - 0.3, 'Token\npurchasing'),
    (base_freezable[0], y_base - 0.3, 'Account\nfreezing'),
    (base_transferable[0], y_base - 0.3, 'Transfer\ncontrol'),
    (base_enumerable[0], y_base - 0.3, 'Token\nenumeration'),
]

for x, y, desc in descriptions:
    ax.text(x, y, desc, ha='center', va='top', fontsize=7, style='italic', color='#555555')

# Add key features boxes
feature_y = 0.8
features_1155 = ['Batch ops', 'Marketplace ready', 'ERC1155Receiver']
features_6909 = ['Minimal gas', 'Granular allowances', '7.9% cheaper']

for i, feat in enumerate(features_1155):
    ax.text(impl_1155[0], feature_y - i*0.25, f'• {feat}',
            ha='center', fontsize=7, color='#666666')

for i, feat in enumerate(features_6909):
    ax.text(impl_6909[0], feature_y - i*0.25, f'• {feat}',
            ha='center', fontsize=7, color='#666666')

# Title
ax.text(7, 9.7, 'EVMAuth Smart Contract Inheritance Hierarchy',
        ha='center', fontsize=14, fontweight='bold')

# Note at bottom
ax.text(7, 0.1,
        'Solid arrows: Inheritance | Dashed arrows: Interface implementation',
        ha='center', fontsize=8, style='italic',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', edgecolor='black'))

plt.tight_layout()
plt.savefig('contract_hierarchy.pdf', dpi=300, bbox_inches='tight')
plt.savefig('contract_hierarchy.png', dpi=300, bbox_inches='tight')
print("✓ Generated: contract_hierarchy.pdf/png")
plt.close()
