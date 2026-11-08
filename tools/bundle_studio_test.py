#!/usr/bin/env python3
"""Print one self-contained source-level Studio Edit fixture to stdout."""

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULES = {
    'Config': 'src/shared/Config.luau',
    'ChainBuilder': 'src/plugin/ChainBuilder.luau',
    'Limits': 'src/shared/Limits.luau',
    'Solver': 'src/shared/Solver.luau',
    'ChainAdapter': 'src/runtime/ChainAdapter.luau',
    'ChainDefinition': 'src/runtime/ChainDefinition.luau',
    'PanelComponents': 'src/plugin/PanelComponents.luau',
    'SurfaceContact': 'src/runtime/SurfaceContact.luau',
    'SurfaceProbe': 'src/runtime/SurfaceProbe.luau',
    'SurfaceContactGizmo': 'src/plugin/SurfaceContactGizmo.luau',
    'ViewportTargetHandle': 'src/plugin/ViewportTargetHandle.luau',
    'WorldGhostSession': 'src/plugin/WorldGhostSession.luau',
    'ChainDiscovery': 'src/plugin/ChainDiscovery.luau',
    'AxisGizmo': 'src/plugin/AxisGizmo.luau',
    'LimitGeometryFactory': 'src/plugin/LimitGeometry.luau',
    'SavedLimitOverlay': 'src/plugin/SavedLimitOverlay.luau',
}
FIXTURES = {
    'PanelComponents': (('PanelComponents',), 'tests/studio/PanelComponents.integration.luau'),
    'SurfaceProbe': (('SurfaceContact', 'SurfaceProbe'), 'tests/studio/SurfaceProbe.integration.luau'),
    'SurfaceContactGizmo': (('SurfaceContactGizmo',), 'tests/studio/SurfaceContactGizmo.integration.luau'),
    'ViewportTargetHandle': (('ViewportTargetHandle',), 'tests/studio/ViewportTargetHandle.integration.luau'),
    'WorldGhostSession': (('Config', 'ChainBuilder', 'Limits', 'Solver', 'ChainAdapter', 'ChainDefinition', 'WorldGhostSession'), 'tests/studio/WorldGhostSession.integration.luau'),
    'ChainDiscovery': (('ChainDiscovery',), 'tests/studio/ChainDiscovery.spec.luau'),
    'SavedLimitOverlay': (('Config', 'AxisGizmo', 'LimitGeometryFactory', 'SavedLimitOverlay'), 'tests/studio/SavedLimitOverlay.integration.luau'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', choices=FIXTURES)
    args = parser.parse_args()
    modules, test = FIXTURES[args.fixture]
    # Read everything before producing output, so a missing file cannot leave a
    # partial program that appears ready to execute.
    sources = [(name, (ROOT / MODULES[name]).read_text()) for name in modules]
    test_source = (ROOT / test).read_text()
    print('-- Generated source-level fixture; does not exercise the installed plugin or real pointer input.')
    print("assert(game:GetService('RunService'):IsEdit(), 'Run this fixture in Studio Edit mode')")
    for name, source in sources:
        print(f'local {name} = (function()\n{source}\nend)()')
    if args.fixture == 'SavedLimitOverlay':
        print('local LimitGeometry = LimitGeometryFactory.new(Config)')
    print(f'local result = (function()\n{test_source}\nend)()')
    print(f"print('Studio source fixture {args.fixture} passed:', result)")
    print('return result')


if __name__ == '__main__':
    main()
