#!/usr/bin/env python3
"""
Master script to generate all EVMAuth paper visualizations
Run this to create all figures at once
"""

import subprocess
import sys
import os

# List of all visualization scripts
scripts = [
    # Cost and Performance Analysis (Results)
    '1_network_cost_comparison.py',
    '2_infrastructure_cost_pie.py',
    '3_tco_line_chart.py',
    '4_deployment_stacked_bar.py',
    '5_operation_costs_radar.py',
    '6_deployment_waterfall.py',
    # Architecture and Design Visualizations
    '7_seven_primitives_wheel.py',
    '8_contract_hierarchy.py',
    '9_multi_currency_pricing.py',
    '10_token_lifecycle.py',
    '11_ai_agent_workflow.py',
    '12_composability_stack.py',
    '13_gas_optimization_tradeoffs.py',
    '14_paradigm_shift.py'
]

def main():
    print("=" * 70)
    print("EVMAuth Paper Visualization Generator")
    print("=" * 70)
    print()

    # Check if matplotlib is installed
    try:
        import matplotlib
        import numpy
        print(f"✓ matplotlib {matplotlib.__version__} found")
        print(f"✓ numpy {numpy.__version__} found")
    except ImportError as e:
        print(f"✗ Missing dependency: {e}")
        print("\nPlease install requirements:")
        print("  pip install -r requirements.txt")
        sys.exit(1)

    print()
    print("Generating visualizations...")
    print("-" * 70)

    failed = []
    for i, script in enumerate(scripts, 1):
        print(f"\n[{i}/{len(scripts)}] Running {script}...")
        try:
            result = subprocess.run([sys.executable, script],
                                   capture_output=True,
                                   text=True,
                                   check=True)
            print(result.stdout.strip())
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to generate {script}")
            print(f"Error: {e.stderr}")
            failed.append(script)
        except Exception as e:
            print(f"✗ Unexpected error: {e}")
            failed.append(script)

    print()
    print("=" * 70)
    if not failed:
        print("✓ All visualizations generated successfully!")
        print()
        print("Generated files:")
        print("\nCost & Performance Analysis:")
        print("  • network_cost_comparison.pdf/png")
        print("  • infrastructure_cost_pie.pdf/png")
        print("  • tco_line_chart.pdf/png")
        print("  • deployment_stacked_bar.pdf/png")
        print("  • operation_costs_radar.pdf/png")
        print("  • deployment_waterfall.pdf/png")
        print("\nArchitecture & Design:")
        print("  • seven_primitives_wheel.pdf/png")
        print("  • contract_hierarchy.pdf/png")
        print("  • multi_currency_pricing.pdf/png")
        print("  • token_lifecycle.pdf/png")
        print("  • ai_agent_workflow.pdf/png")
        print("  • composability_stack.pdf/png")
        print("  • gas_optimization_tradeoffs.pdf/png")
        print("  • paradigm_shift.pdf/png")
    else:
        print(f"✗ {len(failed)} visualization(s) failed:")
        for script in failed:
            print(f"  • {script}")
        sys.exit(1)

    print("=" * 70)

if __name__ == '__main__':
    main()
