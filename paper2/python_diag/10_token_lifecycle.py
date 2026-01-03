#!/usr/bin/env python3
"""
Token Lifecycle State Machine
Finite state machine showing token states and transitions
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle
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

# State colors
color_initial = '#E8F4F8'  # Light blue
color_active = '#D4EDDA'  # Light green
color_transitional = '#FFF3CD'  # Light yellow
color_final = '#F8D7DA'  # Light red

def draw_state(ax, x, y, width, height, text, color, is_initial=False, is_final=False):
    """Draw a state box"""
    if is_final:
        # Double border for final states
        outer_box = FancyBboxPatch((x-0.05, y-0.05), width+0.1, height+0.1,
                                  boxstyle="round,pad=0.1",
                                  edgecolor='black', facecolor='none',
                                  linewidth=3, zorder=1)
        ax.add_patch(outer_box)

    box = FancyBboxPatch((x, y), width, height,
                        boxstyle="round,pad=0.1",
                        edgecolor='black', facecolor=color,
                        linewidth=2, zorder=2)
    ax.add_patch(box)

    if is_initial:
        # Add initial state arrow
        ax.arrow(x - 0.7, y + height/2, 0.5, 0,
                head_width=0.15, head_length=0.15,
                fc='black', ec='black', linewidth=2, zorder=3)

    ax.text(x + width/2, y + height/2, text,
            ha='center', va='center', fontsize=10,
            fontweight='bold', zorder=3)

    return (x + width/2, y + height/2)

def draw_transition(ax, x1, y1, x2, y2, label, curve=0):
    """Draw a transition arrow with label"""
    if curve == 0:
        # Straight arrow
        arrow = FancyArrowPatch((x1, y1), (x2, y2),
                               arrowstyle='-|>',
                               mutation_scale=20,
                               linewidth=2,
                               color='black',
                               zorder=1)
    else:
        # Curved arrow
        arrow = FancyArrowPatch((x1, y1), (x2, y2),
                               arrowstyle='-|>',
                               mutation_scale=20,
                               linewidth=2,
                               color='black',
                               connectionstyle=f"arc3,rad={curve}",
                               zorder=1)
    ax.add_patch(arrow)

    # Label position (midpoint)
    mid_x = (x1 + x2) / 2
    mid_y = (y1 + y2) / 2 + curve * 0.5

    ax.text(mid_x, mid_y, label,
            ha='center', va='bottom', fontsize=8,
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white',
                     edgecolor='black', linewidth=1),
            zorder=4)

# Define states
# Row 1: Creation
created_pos = draw_state(ax, 1, 8, 2, 0.7, 'Created', color_initial, is_initial=True)

# Row 2: Configuration states
config_pos = draw_state(ax, 5.5, 8, 2, 0.7, 'Configured\n(Type & Price)', color_active)

# Row 3: Ownership states
owned_pos = draw_state(ax, 2, 6, 2, 0.7, 'Owned\n(User Balance)', color_active)
frozen_pos = draw_state(ax, 10.5, 6, 2, 0.7, 'Frozen\n(Account)', color_transitional)

# Row 4: Transfer state
transferring_pos = draw_state(ax, 2, 4, 2, 0.7, 'Transferring', color_transitional)

# Row 5: Expiration states
active_pos = draw_state(ax, 6, 4, 2, 0.7, 'Active\n(Not Expired)', color_active)
expired_pos = draw_state(ax, 10, 4, 2, 0.7, 'Expired\n(TTL passed)', color_transitional)

# Row 6: Final states
burned_pos = draw_state(ax, 4, 1.5, 2, 0.7, 'Burned', color_final, is_final=True)
transferred_pos = draw_state(ax, 8, 1.5, 2, 0.7, 'Transferred\nOut', color_final, is_final=True)

# Draw transitions
# Creation flow
draw_transition(ax, created_pos[0] + 1, created_pos[1], config_pos[0] - 1, config_pos[1],
               'createToken()', 0)

# Configuration to Owned
draw_transition(ax, config_pos[0] - 0.5, config_pos[1] - 0.35, owned_pos[0] + 0.5, owned_pos[1] + 0.35,
               'purchase()', -0.3)

# Owned to Frozen
draw_transition(ax, owned_pos[0] + 1, owned_pos[1] + 0.2, frozen_pos[0] - 1.2, frozen_pos[1] + 0.2,
               'freezeAccount()', 0.2)

# Frozen back to Owned
draw_transition(ax, frozen_pos[0] - 1.2, frozen_pos[1] - 0.2, owned_pos[0] + 1, owned_pos[1] - 0.2,
               'unfreezeAccount()', -0.2)

# Owned to Transferring
draw_transition(ax, owned_pos[0], owned_pos[1] - 0.35, transferring_pos[0], transferring_pos[1] + 0.35,
               'transfer() /\nsafeTransferFrom()', 0)

# Transferring to Transferred
draw_transition(ax, transferring_pos[0] + 0.7, transferring_pos[1] - 0.3, transferred_pos[0] - 0.7, transferred_pos[1] + 0.2,
               'Complete', -0.2)

# Owned to Active (time check)
draw_transition(ax, owned_pos[0] + 1.5, owned_pos[1] - 0.35, active_pos[0] - 0.5, active_pos[1] + 0.35,
               'balanceOf()\n[check TTL]', -0.15)

# Active to Expired
draw_transition(ax, active_pos[0] + 1, active_pos[1], expired_pos[0] - 1, expired_pos[1],
               'time > TTL', 0)

# Expired back to Active (extension)
draw_transition(ax, expired_pos[0] - 1, expired_pos[1] + 0.2, active_pos[0] + 1, active_pos[1] + 0.2,
               'purchase()\n[extend]', 0.2)

# Expired to Burned
draw_transition(ax, expired_pos[0] - 0.5, expired_pos[1] - 0.35, burned_pos[0] + 1, burned_pos[1] + 0.35,
               'pruneBalanceRecords()', -0.3)

# Owned to Burned (manual)
draw_transition(ax, owned_pos[0] - 0.5, owned_pos[1] - 0.35, burned_pos[0] - 0.5, burned_pos[1] + 0.35,
               'burn()', -0.4)

# Self-loop: Transferring failed
circle_center = (transferring_pos[0] - 1.2, transferring_pos[1])
self_loop = mpatches.FancyArrowPatch(
    (circle_center[0], circle_center[1] + 0.3),
    (circle_center[0], circle_center[1] - 0.3),
    arrowstyle='-|>',
    mutation_scale=15,
    linewidth=1.5,
    color='red',
    connectionstyle="arc3,rad=1.5"
)
ax.add_patch(self_loop)
ax.text(circle_center[0] - 0.6, circle_center[1], 'Fail:\n!transferable',
        ha='center', fontsize=7, color='red',
        bbox=dict(boxstyle='round,pad=0.2', facecolor='#FFE5E5', edgecolor='red'))

# Add legend
legend_y = 9.5
ax.text(7, legend_y, 'State Types:', fontsize=10, fontweight='bold')

legend_items = [
    (8.5, legend_y - 0.3, color_initial, 'Initial State'),
    (8.5, legend_y - 0.6, color_active, 'Active State'),
    (8.5, legend_y - 0.9, color_transitional, 'Transitional'),
    (8.5, legend_y - 1.2, color_final, 'Final State (Double border)'),
]

for x, y, color, label in legend_items:
    box = FancyBboxPatch((x, y - 0.1), 0.3, 0.2,
                         boxstyle="round,pad=0.02",
                         edgecolor='black', facecolor=color,
                         linewidth=1)
    ax.add_patch(box)
    ax.text(x + 0.4, y, label, va='center', fontsize=8)

# Add conditional transitions note
ax.text(7, 2.5, 'Conditional Transitions:', fontsize=9, fontweight='bold')
ax.text(7, 2.3, '• transfer() only if token.transferable == true', fontsize=8)
ax.text(7, 2.1, '• freezeAccount() only by ACCOUNT_MANAGER role', fontsize=8)
ax.text(7, 1.9, '• Expiration only for ephemeral tokens (TTL > 0)', fontsize=8)

# Title
ax.text(7, 9.7, 'Token Lifecycle State Machine',
        ha='center', fontsize=14, fontweight='bold')

# Note
ax.text(7, 0.5,
        'Solid arrows: User/Admin actions | Dashed: Automatic state checks',
        ha='center', fontsize=8, style='italic',
        bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', edgecolor='black'))

plt.tight_layout()
plt.savefig('token_lifecycle.pdf', dpi=300, bbox_inches='tight')
plt.savefig('token_lifecycle.png', dpi=300, bbox_inches='tight')
print("✓ Generated: token_lifecycle.pdf/png")
plt.close()
