"""Verify offline Studio fixture bundles contain current, scoped source."""

from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools' / 'bundle_studio_test.py'
FIXTURES = {
    'CircularAngularSpeed': ('src/shared/CircularHinge.luau', 'src/shared/Limits.luau', 'src/shared/Solver.luau', 'src/runtime/ChainAdapter.luau', 'tests/studio/CircularAngularSpeed.integration.luau'),
    'ChainPathView': ('src/plugin/ChainPathView.luau', 'tests/studio/ChainPathView.integration.luau'),
    'JointAuthoring': ('src/shared/Config.luau', 'src/plugin/InputProfileBuilder.luau', 'src/plugin/JointAuthoring.luau', 'tests/studio/JointAuthoring.integration.luau'),
    'AxisGizmo': ('src/shared/Config.luau', 'src/plugin/AxisGizmo.luau', 'src/plugin/LimitGeometry.luau', 'tests/studio/AxisGizmo.spec.luau'),
    'LimitGeometry': ('src/shared/Config.luau', 'src/shared/LimitFrame.luau', 'src/plugin/LimitGeometry.luau', 'tests/studio/LimitGeometry.spec.luau'),
    'ConfiguredLimitFrame': ('src/runtime/ChainDefinition.luau', 'src/shared/LimitFrame.luau', 'src/shared/CircularHinge.luau', 'src/shared/Limits.luau', 'src/shared/Solver.luau', 'src/runtime/ChainAdapter.luau', 'tests/studio/ConfiguredLimitFrame.integration.luau'),
    'HingeLimitHandles': ('src/shared/Config.luau', 'src/plugin/AxisGizmo.luau', 'src/plugin/HingeDragMath.luau', 'src/plugin/HingeLimitHandles.luau', 'tests/studio/HingeLimitHandles.integration.luau'),
    'ConfiguredOrientation': ('src/shared/Config.luau', 'src/plugin/ChainBuilder.luau', 'src/runtime/ChainDefinition.luau', 'tests/studio/ConfiguredOrientation.integration.luau'),
    'OrientationChain': ('src/shared/Limits.luau', 'src/shared/Solver.luau', 'src/runtime/ChainAdapter.luau', 'tests/studio/OrientationChain.integration.luau'),
    'SurfaceOrientation': ('src/runtime/SurfaceFrame.luau', 'src/runtime/SurfaceOrientation.luau', 'tests/studio/SurfaceOrientation.integration.luau'),
    'PanelComponents': ('src/plugin/PanelComponents.luau', 'tests/studio/PanelComponents.integration.luau'),
    'SurfaceProbe': ('src/runtime/SurfaceContact.luau', 'src/runtime/SurfaceProbe.luau', 'tests/studio/SurfaceProbe.integration.luau'),
    'SurfaceContactGizmo': ('src/plugin/SurfaceContactGizmo.luau', 'tests/studio/SurfaceContactGizmo.integration.luau'),
    'ViewportTargetHandle': ('src/plugin/ViewportTargetHandle.luau', 'tests/studio/ViewportTargetHandle.integration.luau'),
    'WorldGhostSession': ('src/plugin/WorldGhostSession.luau', 'tests/studio/WorldGhostSession.integration.luau'),
    'ChainDiscovery': ('src/plugin/ChainDiscovery.luau', 'tests/studio/ChainDiscovery.spec.luau'),
    'SavedLimitOverlay': ('src/plugin/SavedLimitOverlay.luau', 'tests/studio/SavedLimitOverlay.integration.luau'),
}


def run(*args):
    return subprocess.run([sys.executable, str(TOOL), *args], cwd=ROOT, capture_output=True, text=True)


class BundleStudioTest(unittest.TestCase):
    def test_known_fixtures_embed_live_source_and_test(self):
        for name, paths in FIXTURES.items():
            with self.subTest(name=name):
                result = run(name)
                self.assertEqual(result.returncode, 0, result.stderr)
                for path in paths:
                    self.assertIn((ROOT / path).read_text(), result.stdout)
                self.assertIn('print(', result.stdout)
                self.assertIn(name, result.stdout)

    def test_ghost_bundle_includes_solver_dependencies(self):
        result = run('WorldGhostSession')
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('Config', 'ChainBuilder', 'Limits', 'Solver', 'ChainAdapter', 'ChainDefinition'):
            self.assertIn('local ' + name + ' = (function()', result.stdout)

    def test_orientation_fixture_dependencies_are_bound_before_use(self):
        fixtures = {
            'ConfiguredOrientation': ('Config', 'ChainBuilder', 'ChainDefinition'),
            'OrientationChain': ('Limits', 'Solver', 'ChainAdapter'),
            'SurfaceOrientation': ('SurfaceFrame', 'SurfaceOrientation'),
        }
        for fixture, modules in fixtures.items():
            with self.subTest(fixture=fixture):
                result = run(fixture)
                self.assertEqual(result.returncode, 0, result.stderr)
                body = result.stdout.index('local result = (function()')
                for name in modules:
                    self.assertLess(result.stdout.index('local ' + name + ' = (function()'), body)

    def test_saved_guides_bundle_initializes_real_geometry(self):
        result = run('SavedLimitOverlay')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('local LimitGeometry = LimitGeometryFactory.new(Config)', result.stdout)

    def test_axis_gizmo_bundle_exposes_geometry_factory(self):
        result = run('AxisGizmo')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('local LimitGeometry = LimitGeometryFactory\n', result.stdout)

    def test_limit_frame_fixtures_bind_dependencies_before_test(self):
        fixtures = {
            'LimitGeometry': ('Config', 'LimitFrame', 'LimitGeometryFactory'),
            'ConfiguredLimitFrame': ('ChainDefinition', 'LimitFrame', 'CircularHinge', 'Limits', 'Solver', 'ChainAdapter'),
        }
        for fixture, modules in fixtures.items():
            with self.subTest(fixture=fixture):
                result = run(fixture)
                self.assertEqual(result.returncode, 0, result.stderr)
                body = result.stdout.index('local result = (function()')
                for name in modules:
                    self.assertLess(result.stdout.index('local ' + name + ' = (function()'), body)
                if fixture == 'LimitGeometry':
                    self.assertLess(result.stdout.index('local LimitGeometry = LimitGeometryFactory\n'), body)

    def test_unknown_and_missing_fixture_fail_without_luau_output(self):
        for args in ((), ('unknown',), ('../PanelComponents',)):
            with self.subTest(args=args):
                result = run(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertTrue(result.stderr)


if __name__ == '__main__':
    unittest.main()
