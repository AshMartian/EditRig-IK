#!/usr/bin/env python3
"""Print one self-contained source-level Studio Edit fixture to stdout."""

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULES = {
    'Config': 'src/shared/Config.luau',
    'LimitFrame': 'src/shared/LimitFrame.luau',
    'ChainBuilder': 'src/plugin/ChainBuilder.luau',
    'Limits': 'src/shared/Limits.luau',
    'Solver': 'src/shared/Solver.luau',
    'ChainAdapter': 'src/runtime/ChainAdapter.luau',
    'ChainDefinition': 'src/runtime/ChainDefinition.luau',
    'PanelComponents': 'src/plugin/PanelComponents.luau',
    'JointAuthoring': 'src/plugin/JointAuthoring.luau',
    'InputProfileBuilder': 'src/plugin/InputProfileBuilder.luau',
    'SurfaceContact': 'src/runtime/SurfaceContact.luau',
    'SurfaceFrame': 'src/runtime/SurfaceFrame.luau',
    'SurfaceOrientation': 'src/runtime/SurfaceOrientation.luau',
    'SurfaceProbe': 'src/runtime/SurfaceProbe.luau',
    'SurfaceContactGizmo': 'src/plugin/SurfaceContactGizmo.luau',
    'ViewportTargetHandle': 'src/plugin/ViewportTargetHandle.luau',
    'WorldGhostSession': 'src/plugin/WorldGhostSession.luau',
    'ChainDiscovery': 'src/plugin/ChainDiscovery.luau',
    'ChainPathView': 'src/plugin/ChainPathView.luau',
    'AxisGizmo': 'src/plugin/AxisGizmo.luau',
    'HingeDragMath': 'src/plugin/HingeDragMath.luau',
    'HingeLimitHandles': 'src/plugin/HingeLimitHandles.luau',
    'LimitGeometryFactory': 'src/plugin/LimitGeometry.luau',
    'SavedLimitOverlay': 'src/plugin/SavedLimitOverlay.luau',
}
FIXTURES = {
    'ChainPathView': (('ChainPathView',), 'tests/studio/ChainPathView.integration.luau'),
    'JointAuthoring': (('Config', 'InputProfileBuilder', 'JointAuthoring'), 'tests/studio/JointAuthoring.integration.luau'),
    'AxisGizmo': (('Config', 'AxisGizmo', 'LimitGeometryFactory'), 'tests/studio/AxisGizmo.spec.luau'),
    'LimitGeometry': (('Config', 'LimitFrame', 'LimitGeometryFactory'), 'tests/studio/LimitGeometry.spec.luau'),
    'ConfiguredLimitFrame': (('ChainDefinition', 'LimitFrame', 'Limits', 'Solver', 'ChainAdapter'), 'tests/studio/ConfiguredLimitFrame.integration.luau'),
    'HingeLimitHandles': (('Config', 'AxisGizmo', 'HingeDragMath', 'HingeLimitHandles'), 'tests/studio/HingeLimitHandles.integration.luau'),
    'ConfiguredOrientation': (('Config', 'ChainBuilder', 'ChainDefinition'), 'tests/studio/ConfiguredOrientation.integration.luau'),
    'OrientationChain': (('Limits', 'Solver', 'ChainAdapter'), 'tests/studio/OrientationChain.integration.luau'),
    'SurfaceOrientation': (('SurfaceFrame', 'SurfaceOrientation'), 'tests/studio/SurfaceOrientation.integration.luau'),
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
    if args.fixture in ('AxisGizmo', 'LimitGeometry'):
        print('local LimitGeometry = LimitGeometryFactory')
    elif args.fixture == 'SavedLimitOverlay':
        print('local LimitGeometry = LimitGeometryFactory.new(Config)')
    print(f'local result = (function()\n{test_source}\nend)()')
    print(f"print('Studio source fixture {args.fixture} passed:', result)")
    print('return result')


if __name__ == '__main__':
    main()
