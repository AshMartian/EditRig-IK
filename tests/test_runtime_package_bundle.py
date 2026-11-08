"""The Studio runtime-package fixture must contain the actual built plugin sources."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools' / 'bundle_runtime_package_test.py'


class RuntimePackageBundleTest(unittest.TestCase):
    def test_embeds_complete_built_runtime_and_test(self):
        result = subprocess.run([sys.executable, str(TOOL)], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        tree = json.loads((ROOT / 'runtime.project.json').read_text())['tree']
        self.assertIn((ROOT / tree['$path']).read_text(), result.stdout)
        self.assertIn((ROOT / 'src/plugin/RuntimeInstaller.luau').read_text(), result.stdout)
        self.assertIn((ROOT / 'tests/studio/RuntimePackage.integration.luau').read_text(), result.stdout)
        for name, value in tree.items():
            if name.startswith('$'):
                continue
            with self.subTest(module=name):
                self.assertIn('RuntimeComponents[' + json.dumps(name) + ']', result.stdout)
                self.assertIn((ROOT / value['$path']).read_text(), result.stdout)
        self.assertIn('RuntimeComponents["LimitFrame"]', result.stdout)

    def test_failed_build_writes_no_partial_luau(self):
        env = {**os.environ, 'ROJO_BIN': '/no/such/rojo'}
        result = subprocess.run([sys.executable, str(TOOL)], cwd=ROOT, env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
