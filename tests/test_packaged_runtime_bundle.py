"""Verify packaged-runtime Studio bundle generation and safe source encoding."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools' / 'bundle_packaged_runtime_test.py'

class PackagedRuntimeBundleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('runtime_bundle', TOOL)
        cls.bundle = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.bundle)

    def test_luau_long_literal_handles_all_closing_delimiters(self):
        source = 'alpha ]] beta ]=] gamma ]==] delta\n'
        literal = self.bundle.long_literal(source)
        self.assertEqual(literal, '[===[\n' + source + ']===]')

    def test_rejects_unexpected_child_and_duplicate_names(self):
        def item(name, cls='ModuleScript'):
            root = ET.Element('Item', {'class': cls})
            props = ET.SubElement(root, 'Properties')
            ET.SubElement(props, 'string', {'name': 'Name'}).text = name
            ET.SubElement(props, 'string', {'name': 'Source'}).text = 'return {}'
            return root
        parent = item('runtime')
        parent.append(item('child'))
        parent.append(item('child'))
        with self.assertRaises(ValueError):
            self.bundle.render(parent, '')
        parent.remove(parent[-1])
        parent.append(item('unexpected', 'Script'))
        with self.assertRaises(ValueError):
            self.bundle.render(parent, '')

    def test_build_emits_current_packaged_modules_and_fixture(self):
        result = subprocess.run([sys.executable, str(TOOL)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn((ROOT / 'src/runtime/SurfaceContact.luau').read_text(), result.stdout)
        self.assertIn((ROOT / 'src/runtime/SurfaceProbe.luau').read_text(), result.stdout)
        self.assertIn((ROOT / 'tests/studio/PackagedSurfaceContact.integration.luau').read_text(), result.stdout)
        self.assertIn("require(runtimeModule)", result.stdout)
        self.assertIn("fixtureFolder:Destroy()", result.stdout)

    def test_failed_build_emits_no_partial_program(self):
        env = dict(os.environ, ROJO_BIN='/missing/editrig-test-rojo')
        result = subprocess.run([sys.executable, str(TOOL)], cwd=ROOT, capture_output=True, text=True, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

if __name__ == '__main__':
    unittest.main()
