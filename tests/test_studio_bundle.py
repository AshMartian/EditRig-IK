"""Verify offline Studio fixture bundles contain current, scoped source."""

from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools' / 'bundle_studio_test.py'
FIXTURES = {
    'PanelComponents': ('src/plugin/PanelComponents.luau', 'tests/studio/PanelComponents.integration.luau'),
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

    def test_saved_guides_bundle_initializes_real_geometry(self):
        result = run('SavedLimitOverlay')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('local LimitGeometry = LimitGeometryFactory.new(Config)', result.stdout)

    def test_unknown_and_missing_fixture_fail_without_luau_output(self):
        for args in ((), ('unknown',), ('../PanelComponents',)):
            with self.subTest(args=args):
                result = run(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertTrue(result.stderr)


if __name__ == '__main__':
    unittest.main()
