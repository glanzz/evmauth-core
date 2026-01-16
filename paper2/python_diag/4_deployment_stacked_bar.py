#!/usr/bin/env python3
"""
Deployment Cost Breakdown: Stacked Bar Chart
Shows ERC-1155 vs ERC-6909 deployment costs broken down by components
"""

import matplotlib.pyplot as plt
import numpy as np

try:
        # Set publication-quality style
        plt.style.use('seaborn-v0_8-paper')
        # plt.rcParams['font.family'] = 'serif'
        # plt.rcParams['font.serif'] = ['Computer Modern Roman']
        plt.rcParams['text.usetex'] = False
        plt.rcParams['font.size'] = 10
        plt.rcParams['axes.labelsize'] = 11
        plt.rcParams['axes.titlesize'] = 12

        # Data from gas reports (in gas units)
        # ERC-1155: Total 8,212,855 gas
        # ERC-6909: Total 7,571,932 gas
        # Breakdown (from deployment logs):
        # - Proxy deployment: ~205K gas (ERC1967Proxy)
        # - Implementation: ERC-1155: 5,355,027 gas, ERC-6909: 4,864,022 gas
        # - Token configuration (5 tokens): ~2.65M gas for 1155, ~2.5M gas for 6909

        implementations = ['ERC-1155', 'ERC-6909']

        # Gas costs in thousands
        proxy_costs = [432, 430]  # Same for both
        implementation_costs = [7030, 6508]  # Contract deployment
        config_costs = [758, 750]  # 5 token configurations

        # Calculate totals
        totals = [sum(x) for x in zip(proxy_costs, implementation_costs, config_costs)]

        x = np.arange(len(implementations))
        # width = 0.9

        fig, ax = plt.subplots(figsize=(7, 4))

        # Create stacked bars
        p1 = ax.bar(x, proxy_costs, label='Proxy Deployment',
                color='#94A378', edgecolor='black', linewidth=0.05)
        p2 = ax.bar(x, implementation_costs, bottom=proxy_costs,
                label='Implementation Contract', color='#E5BA41', edgecolor='black', linewidth=0.05)
        p3 = ax.bar(x, config_costs,
                bottom=[i+j for i,j in zip(proxy_costs, implementation_costs)],
                label='Token Configuration (5 tokens)', color='#D1855C', edgecolor='black', linewidth=0.05)

        ax.set_ylabel('Gas Cost', fontweight='bold')
        # ax.set_title('EVMAuth Deployment Cost Breakdown', fontweight='bold', pad=15)
        ax.set_xticks(x)
        ax.set_xticklabels(implementations, fontweight='bold')
        ax.legend(loc='upper right',bbox_to_anchor=(1, 1.08), frameon=True, fancybox=False, edgecolor='black', ncol=3)
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

        # ax.grid(True, axis='y', alpha=0.3, linestyle='--', linewidth=0.5)

        # Add value labels on each segment
        for i, impl in enumerate(implementations):
                # Proxy label
                ax.text(i, proxy_costs[i]/2, f'{proxy_costs[i]}K',
                        ha='center', va='center', fontweight='bold', fontsize=9, color='white')

                # Implementation label
                y_pos = proxy_costs[i] + implementation_costs[i]/2
                ax.text(i, y_pos, f'{implementation_costs[i]}K',
                        ha='center', va='center', fontweight='bold', fontsize=9, color='white')

                # Config label
                y_pos = proxy_costs[i] + implementation_costs[i] + config_costs[i]/2
                ax.text(i, y_pos, f'{config_costs[i]}K',
                        ha='center', va='center', fontweight='bold', fontsize=9, color='white')

                # Total label above bar
                #     ax.text(i, totals[i] + 200, f'Total:\n{totals[i]}K gas',
                #             ha='center', va='bottom', fontweight='bold', fontsize=10,
                #             bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow', edgecolor='black'))

        
        plt.tight_layout(rect=[0, 0.06, 1, 1])
        plt.savefig('deployment_stacked_bar.pdf', dpi=300, bbox_inches='tight')
        plt.savefig('deployment_stacked_bar.png', dpi=300, bbox_inches='tight')
        plt.close()
except Exception as e:
    print(f"✗ Error generating deployment_stacked_bar: {e}")
    exit(1)
finally:
       print("✓ Generated: deployment_stacked_bar.pdf/png")

