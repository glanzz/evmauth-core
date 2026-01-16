#!/usr/bin/env python3
"""
AI Agent Authentication Workflow Comparison
Flowchart comparing Traditional/OAuth/EVMAuth for AI agent authentication
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

fig, axes = plt.subplots(1, 3, figsize=(16, 10))

# Colors
color_problem = '#F8D7DA'  # Light red - problem/limitation
color_action = '#D4EDDA'  # Light green - action
color_check = '#FFF3CD'  # Light yellow - decision point
color_success = '#D1ECF1'  # Light blue - success

def draw_box(ax, x, y, width, height, text, color, shape='round'):
    """Draw a flowchart box"""
    if shape == 'diamond':
        # Decision diamond
        points = np.array([
            [x + width/2, y + height],  # top
            [x + width, y + height/2],  # right
            [x + width/2, y],  # bottom
            [x, y + height/2]  # left
        ])
        polygon = mpatches.Polygon(points, closed=True,
                                  edgecolor='black', facecolor=color,
                                  linewidth=2)
        ax.add_patch(polygon)
    else:
        # Rectangle with rounded corners
        box = FancyBboxPatch((x, y), width, height,
                            boxstyle="round,pad=0.05",
                            edgecolor='black', facecolor=color,
                            linewidth=2)
        ax.add_patch(box)

    ax.text(x + width/2, y + height/2, text,
            ha='center', va='center', fontsize=8,
            fontweight='bold', wrap=True)

    return (x + width/2, y + height/2)

def draw_arrow(ax, x1, y1, x2, y2, label='', color='black', style='solid'):
    """Draw an arrow between boxes"""
    linestyle = '-' if style == 'solid' else '--'
    arrow = FancyArrowPatch((x1, y1), (x2, y2),
                           arrowstyle='-|>',
                           mutation_scale=15,
                           linewidth=2,
                           color=color,
                           linestyle=linestyle,
                           zorder=1)
    ax.add_patch(arrow)

    if label:
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        ax.text(mid_x + 0.1, mid_y, label,
                ha='left', va='center', fontsize=7,
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white',
                         edgecolor='gray', linewidth=0.5))

# =============================================================================
# APPROACH 1: TRADITIONAL (Static API Keys)
# =============================================================================
ax1 = axes[0]
ax1.set_xlim(0, 3)
ax1.set_ylim(0, 10)
ax1.axis('off')
ax1.set_title('Traditional: Static API Keys', fontsize=12, fontweight='bold', pad=10)

# Flowchart
start = draw_box(ax1, 0.5, 9, 2, 0.5, 'AI Agent\nNeeds Access', color_action)
key_gen = draw_box(ax1, 0.5, 8, 2, 0.5, 'Admin Generates\nAPI Key', color_action)
manual = draw_box(ax1, 0.5, 7, 2, 0.5, 'Manual Key\nInjection', color_problem)
stored = draw_box(ax1, 0.5, 6, 2, 0.5, 'Key Stored\nin Memory', color_problem)
request = draw_box(ax1, 0.5, 5, 2, 0.5, 'Agent Makes\nAPI Request', color_action)
validate = draw_box(ax1, 0.5, 4, 2, 0.5, 'Server Validates\nKey', color_check)
access = draw_box(ax1, 0.5, 3, 2, 0.5, 'Access Granted', color_success)

# Arrows
draw_arrow(ax1, 1.5, 9, 1.5, 8.5)
draw_arrow(ax1, 1.5, 8, 1.5, 7.5)
draw_arrow(ax1, 1.5, 7, 1.5, 6.5)
draw_arrow(ax1, 1.5, 6, 1.5, 5.5)
draw_arrow(ax1, 1.5, 5, 1.5, 4.5)
draw_arrow(ax1, 1.5, 4, 1.5, 3.5)

# Problems annotation
ax1.text(1.5, 2, '⚠ Problems:', ha='center', fontsize=9, fontweight='bold', color='red')
ax1.text(1.5, 1.5, '• Requires human intervention', ha='center', fontsize=7)
ax1.text(1.5, 1.2, '• Keys can leak or expire', ha='center', fontsize=7)
ax1.text(1.5, 0.9, '• No autonomous rotation', ha='center', fontsize=7)
ax1.text(1.5, 0.6, '• Centralized control point', ha='center', fontsize=7)

# =============================================================================
# APPROACH 2: OAUTH (Human Consent Required)
# =============================================================================
ax2 = axes[1]
ax2.set_xlim(0, 3)
ax2.set_ylim(0, 10)
ax2.axis('off')
ax2.set_title('OAuth: Human Consent Required', fontsize=12, fontweight='bold', pad=10)

# Flowchart
start2 = draw_box(ax2, 0.5, 9, 2, 0.5, 'AI Agent\nNeeds Access', color_action)
redirect = draw_box(ax2, 0.5, 8, 2, 0.5, 'Redirect to\nAuth Server', color_action)
human = draw_box(ax2, 0.5, 7, 2, 0.5, 'Human Login\nRequired', color_problem, shape='diamond')
consent = draw_box(ax2, 0.5, 6, 2, 0.5, 'User Grants\nPermission', color_problem)
token = draw_box(ax2, 0.5, 5, 2, 0.5, 'Receive Access\nToken (TTL)', color_action)
request2 = draw_box(ax2, 0.5, 4, 2, 0.5, 'Agent Makes\nAPI Request', color_action)
expired = draw_box(ax2, 0.5, 3, 2, 0.5, 'Token Expired?', color_check, shape='diamond')

# Arrows
draw_arrow(ax2, 1.5, 9, 1.5, 8.5)
draw_arrow(ax2, 1.5, 8, 1.5, 7.5)
draw_arrow(ax2, 1.5, 7, 1.5, 6.5)
draw_arrow(ax2, 1.5, 6, 1.5, 5.5)
draw_arrow(ax2, 1.5, 5, 1.5, 4.5)
draw_arrow(ax2, 1.5, 4, 1.5, 3.5)

# Refresh loop
draw_arrow(ax2, 0.5, 3.25, 0.2, 7, 'Yes:\nRefresh', 'red', 'dashed')

# Problems annotation
ax2.text(1.5, 2, '⚠ Problems:', ha='center', fontsize=9, fontweight='bold', color='red')
ax2.text(1.5, 1.5, '• Requires human in the loop', ha='center', fontsize=7)
ax2.text(1.5, 1.2, '• Not truly autonomous', ha='center', fontsize=7)
ax2.text(1.5, 0.9, '• Refresh tokens still expire', ha='center', fontsize=7)
ax2.text(1.5, 0.6, '• Complex flow for agents', ha='center', fontsize=7)

# =============================================================================
# APPROACH 3: EVMAUTH (Autonomous Token Ownership)
# =============================================================================
ax3 = axes[2]
ax3.set_xlim(0, 3)
ax3.set_ylim(0, 10)
ax3.axis('off')
ax3.set_title('EVMAuth: Autonomous Ownership', fontsize=12, fontweight='bold', pad=10)

# Flowchart
start3 = draw_box(ax3, 0.5, 9, 2, 0.5, 'AI Agent\nNeeds Access', color_action)
wallet = draw_box(ax3, 0.5, 8, 2, 0.5, 'Agent Has\nEOA Wallet', color_success)
purchase = draw_box(ax3, 0.5, 7, 2, 0.5, 'Purchase Token\nOn-Chain', color_action)
owned = draw_box(ax3, 0.5, 6, 2, 0.5, 'Token Owned\nin Wallet', color_success)
request3 = draw_box(ax3, 0.5, 5, 2, 0.5, 'Sign Challenge\nwith Private Key', color_action)
verify = draw_box(ax3, 0.5, 4, 2, 0.5, 'Server Verifies\nbalanceOf()', color_check)
access3 = draw_box(ax3, 0.5, 3, 2, 0.5, 'Access Granted', color_success)

# Arrows
draw_arrow(ax3, 1.5, 9, 1.5, 8.5)
draw_arrow(ax3, 1.5, 8, 1.5, 7.5)
draw_arrow(ax3, 1.5, 7, 1.5, 6.5)
draw_arrow(ax3, 1.5, 6, 1.5, 5.5)
draw_arrow(ax3, 1.5, 5, 1.5, 4.5)
draw_arrow(ax3, 1.5, 4, 1.5, 3.5)

# Renewal loop (optional)
draw_arrow(ax3, 2.5, 6.25, 2.8, 7, 'Extend\n(Optional)', '#6A994E', 'dashed')
draw_arrow(ax3, 2.8, 7, 2.5, 7.25, '', '#6A994E', 'dashed')

# Benefits annotation
ax3.text(1.5, 2, '✓ Benefits:', ha='center', fontsize=9, fontweight='bold', color='green')
ax3.text(1.5, 1.5, '• Fully autonomous', ha='center', fontsize=7)
ax3.text(1.5, 1.2, '• No human intervention', ha='center', fontsize=7)
ax3.text(1.5, 0.9, '• Transferable credentials', ha='center', fontsize=7)
ax3.text(1.5, 0.6, '• Decentralized verification', ha='center', fontsize=7)

# Main title
fig.suptitle('AI Agent Authentication: Workflow Comparison',
             fontsize=14, fontweight='bold', y=0.98)

# Footer note
fig.text(0.5, 0.02,
         'EVMAuth enables true autonomous operation: agents own tokens directly without human-in-the-loop consent flows',
         ha='center', fontsize=9, style='italic',
         bbox=dict(boxstyle='round,pad=0.4', facecolor='lightgreen', edgecolor='darkgreen', linewidth=2))

plt.tight_layout(rect=[0, 0.04, 1, 0.96])
plt.savefig('ai_agent_workflow.pdf', dpi=300, bbox_inches='tight')
plt.savefig('ai_agent_workflow.png', dpi=300, bbox_inches='tight')
print("✓ Generated: ai_agent_workflow.pdf/png")
plt.close()
