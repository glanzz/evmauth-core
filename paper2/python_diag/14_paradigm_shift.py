#!/usr/bin/env python3
"""
Authorization-as-Asset Paradigm Shift
Before/After comparison: OAuth centralized vs EVMAuth decentralized
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Polygon
import numpy as np

# Set publication-quality style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Computer Modern Roman']
plt.rcParams['text.usetex'] = False
plt.rcParams['font.size'] = 9

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 10))

# Colors
color_user = '#3498DB'  # Blue
color_server = '#E74C3C'  # Red
color_db = '#95A5A6'  # Gray
color_token = '#6A994E'  # Green
color_blockchain = '#2E86AB'  # Dark blue

def draw_node(ax, x, y, radius, label, color, sublabel=''):
    """Draw a circular node"""
    circle = Circle((x, y), radius, color=color, ec='black', linewidth=2, zorder=3)
    ax.add_patch(circle)
    ax.text(x, y, label, ha='center', va='center', fontsize=10,
            fontweight='bold', zorder=4)
    if sublabel:
        ax.text(x, y - radius - 0.3, sublabel, ha='center', va='top',
                fontsize=7, style='italic')

def draw_box(ax, x, y, width, height, label, color, sublabel=''):
    """Draw a rectangular box"""
    box = FancyBboxPatch((x, y), width, height,
                         boxstyle="round,pad=0.1",
                         edgecolor='black', facecolor=color,
                         linewidth=2, zorder=3)
    ax.add_patch(box)
    ax.text(x + width/2, y + height/2, label,
            ha='center', va='center', fontsize=10,
            fontweight='bold', zorder=4)
    if sublabel:
        ax.text(x + width/2, y - 0.3, sublabel,
                ha='center', va='top', fontsize=7, style='italic')

def draw_arrow(ax, x1, y1, x2, y2, label='', style='solid', color='black', width=2):
    """Draw an arrow with optional label"""
    linestyle = '-' if style == 'solid' else '--'
    arrow = FancyArrowPatch((x1, y1), (x2, y2),
                           arrowstyle='-|>',
                           mutation_scale=20,
                           linewidth=width,
                           color=color,
                           linestyle=linestyle,
                           zorder=2)
    ax.add_patch(arrow)

    if label:
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        ax.text(mid_x, mid_y + 0.2, label,
                ha='center', va='bottom', fontsize=7,
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white',
                         edgecolor='gray', linewidth=1),
                zorder=5)

# =============================================================================
# LEFT: Traditional OAuth (Centralized)
# =============================================================================
ax1.set_xlim(0, 10)
ax1.set_ylim(0, 10)
ax1.axis('off')
ax1.set_title('Traditional: Centralized Credential Storage',
              fontsize=12, fontweight='bold', pad=10)

# Central auth server (top)
draw_box(ax1, 3, 8, 4, 1.2, 'Auth Server\n(OAuth Provider)', color_server,
         'Auth0, Cognito, Keycloak')

# Database cluster (middle)
draw_box(ax1, 1.5, 5.5, 2, 1, 'User DB\n(PostgreSQL)', color_db,
         'Users, emails, passwords')
draw_box(ax1, 4, 5.5, 2, 1, 'Session DB\n(Redis)', color_db,
         'Active sessions, tokens')
draw_box(ax1, 6.5, 5.5, 2, 1, 'Permissions\n(MongoDB)', color_db,
         'Roles, scopes, ACLs')

# Application server (bottom middle)
draw_box(ax1, 3, 3.5, 4, 1, 'Application Server\n(API Gateway)', '#F39C12',
         'Validates bearer tokens')

# Users (bottom)
draw_node(ax1, 1.5, 1.5, 0.6, 'User A', color_user, 'Web app')
draw_node(ax1, 5, 1.5, 0.6, 'User B', color_user, 'Mobile app')
draw_node(ax1, 8.5, 1.5, 0.6, 'User C', color_user, 'AI agent')

# Arrows: Auth Server ↔ Databases
draw_arrow(ax1, 4.5, 8, 3, 6.5, 'Query', 'dashed', '#E74C3C', 1.5)
draw_arrow(ax1, 5.5, 8, 5.5, 6.5, 'Read/Write', 'dashed', '#E74C3C', 1.5)
draw_arrow(ax1, 6, 8, 7, 6.5, 'Check ACL', 'dashed', '#E74C3C', 1.5)

# Arrows: Users → App → Auth
draw_arrow(ax1, 1.5, 2.1, 4, 3.5, '1. Login', 'solid', color_user)
draw_arrow(ax1, 5, 2.1, 5, 3.5, '2. Request', 'solid', color_user)
draw_arrow(ax1, 5, 4.5, 5, 8, '3. Validate', 'solid', '#F39C12')

# Problems box
problems = [
    '⚠ Single Point of Failure',
    '⚠ Vendor Lock-in',
    '⚠ Data Breaches (honeypot)',
    '⚠ Service Downtime',
    '⚠ High Infrastructure Costs',
    '⚠ No User Ownership'
]

problem_y = 9.5
for i, problem in enumerate(problems):
    ax1.text(0.2, problem_y - i*0.3, problem,
             ha='left', va='top', fontsize=7, color='red')

# Data flow annotation
ax1.annotate('', xy=(9, 5), xytext=(9, 8),
            arrowprops=dict(arrowstyle='<->', lw=2, color='red'))
ax1.text(9.3, 6.5, 'Constant\nServer\nQueries',
         fontsize=7, color='red', fontweight='bold')

# =============================================================================
# RIGHT: EVMAuth (Decentralized)
# =============================================================================
ax2.set_xlim(0, 10)
ax2.set_ylim(0, 10)
ax2.axis('off')
ax2.set_title('EVMAuth: Decentralized Token Ownership',
              fontsize=12, fontweight='bold', pad=10)

# Blockchain layer (top)
draw_box(ax2, 1.5, 7.5, 7, 1.5, 'Blockchain (Immutable State)',
         color_blockchain, 'Ethereum, Base L2, Arbitrum, etc.')

# Smart contract (inside blockchain)
draw_box(ax2, 3, 8.2, 4, 0.8, 'EVMAuth Contract\n(ERC-1155/6909)',
         color_token)

# Application server (stateless)
draw_box(ax2, 3, 5, 4, 1, 'Application Server\n(Stateless)', '#27AE60',
         'Calls balanceOf() on-chain')

# Users with wallets (bottom)
draw_node(ax2, 1.5, 2.5, 0.6, 'User A', color_user, 'MetaMask')
draw_box(ax2, 0.7, 1.3, 1.6, 0.4, 'Token: Premium\nBalance: 1', color_token)

draw_node(ax2, 5, 2.5, 0.6, 'User B', color_user, 'WalletConnect')
draw_box(ax2, 4.2, 1.3, 1.6, 0.4, 'Token: Basic\nBalance: 2', color_token)

draw_node(ax2, 8.5, 2.5, 0.6, 'User C', color_user, 'EOA (AI)')
draw_box(ax2, 7.7, 1.3, 1.6, 0.4, 'Token: AI Agent\nBalance: 1', color_token)

# Arrows: Users → App
draw_arrow(ax2, 1.5, 3.1, 4, 5, '1. Sign Challenge', 'solid', color_user)
draw_arrow(ax2, 5, 3.1, 5.5, 5, '2. API Request', 'solid', color_user)

# Arrow: App → Blockchain
draw_arrow(ax2, 5, 6, 5, 7.5, '3. balanceOf(address)', 'solid', '#27AE60', 2.5)
draw_arrow(ax2, 5.5, 7.5, 5.5, 6, '4. Return balance', 'dashed', color_blockchain, 1.5)

# Peer-to-peer transfers
draw_arrow(ax2, 2.1, 2.5, 4.4, 2.5, 'Transfer Token', 'dashed', color_token, 1.5)
ax2.text(3.25, 3, 'P2P Transfer\n(No intermediary)',
         ha='center', fontsize=7, fontweight='bold', color=color_token,
         bbox=dict(boxstyle='round,pad=0.2', facecolor='lightgreen', edgecolor='green'))

# Benefits box
benefits = [
    '✓ Self-Sovereign Assets',
    '✓ No Single Point of Failure',
    '✓ Peer-to-Peer Transfers',
    '✓ Immutable Verification',
    '✓ Low Infrastructure Cost',
    '✓ Always Available (24/7)'
]

benefit_y = 9.5
for i, benefit in enumerate(benefits):
    ax2.text(9.8, benefit_y - i*0.3, benefit,
             ha='right', va='top', fontsize=7, color='green')

# Data sovereignty annotation
sovereignty_points = np.array([
    [0.5, 2.5],
    [1.5, 3.7],
    [5, 3.7],
    [8.5, 3.7],
    [9.5, 2.5],
    [9.5, 0.8],
    [0.5, 0.8]
])
sovereignty_box = Polygon(sovereignty_points, closed=True,
                         fill=False, edgecolor='green',
                         linewidth=3, linestyle='--', zorder=1)
ax2.add_patch(sovereignty_box)

ax2.text(5, 0.3, 'User Ownership Zone: Credentials stored in user wallets, not servers',
         ha='center', fontsize=8, fontweight='bold', color='green',
         bbox=dict(boxstyle='round,pad=0.3', facecolor='lightgreen',
                  edgecolor='darkgreen', linewidth=2))

# Main title
fig.suptitle('Authorization Paradigm Shift: From Credentials to Assets',
             fontsize=14, fontweight='bold', y=0.98)

# Footer comparison
comparison_text = """
Traditional OAuth: Authorization = Database Records (centralized, mutable, vendor-controlled)
EVMAuth: Authorization = Blockchain Tokens (decentralized, immutable, user-owned)
"""

fig.text(0.5, 0.02, comparison_text,
         ha='center', fontsize=9, style='italic',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='lightyellow',
                  edgecolor='black', linewidth=2))

plt.tight_layout(rect=[0, 0.05, 1, 0.96])
plt.savefig('paradigm_shift.pdf', dpi=300, bbox_inches='tight')
plt.savefig('paradigm_shift.png', dpi=300, bbox_inches='tight')
print("✓ Generated: paradigm_shift.pdf/png")
plt.close()
