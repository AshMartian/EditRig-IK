#!/usr/bin/env python3
"""Build runtime XML and emit a self-cleaning Studio Edit integration fixture."""
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'tests/studio/PackagedSurfaceContact.integration.luau'


def long_literal(value):
    """Encode arbitrary source in a Luau long string without delimiter injection."""
    equals = ''
    while ']' + equals + ']' in value:
        equals += '='
    # Luau removes one newline directly following a long-string opener.
    return '[' + equals + '[\n' + value + ']' + equals + ']'


def properties(item):
    if item.get('class') != 'ModuleScript':
        raise ValueError('the runtime package must contain only ModuleScripts')
    def prop(name):
        element = item.find('./Properties/string[@name="' + name + '"]')
        if element is None:
            raise ValueError('ModuleScript is missing ' + name)
        return element.text or ''
    name, source = prop('Name'), prop('Source')
    if not name or not source:
        raise ValueError('ModuleScript name and source must not be empty')
    return name, source


def render(root, fixture):
    lines = [
        '-- Generated from the current Rojo-built runtime; run only in Studio Edit.',
        "assert(game:GetService('RunService'):IsEdit(), 'Run this fixture in Studio Edit mode')",
        "assert(not workspace:FindFirstChild('EditRigIKPackagedRuntimeFixture'), 'Remove the previous fixture before running')",
        "local fixtureFolder=Instance.new('Folder')",
        "fixtureFolder.Name='EditRigIKPackagedRuntimeFixture'",
        'fixtureFolder.Archivable=false',
        'fixtureFolder.Parent=workspace',
        'local ok, result=xpcall(function()',
    ]
    count = 0
    def add(item, parent):
        nonlocal count
        name, source = properties(item)
        variable = 'module' + str(count)
        count += 1
        lines.extend([
            f"local {variable}=Instance.new('ModuleScript')",
            f'{variable}.Name={long_literal(name)}',
            f'{variable}.Source={long_literal(source)}',
            f'{variable}.Parent={parent}',
        ])
        seen = set()
        for child in item.findall('./Item'):
            child_name, _ = properties(child)
            if child_name in seen:
                raise ValueError('duplicate ModuleScript name: ' + child_name)
            seen.add(child_name)
            add(child, variable)
        return variable
    root_name = add(root, 'fixtureFolder')
    lines.extend([
        f'local runtimeModule={root_name}',
        'local Runtime=require(runtimeModule)',
        'return (function(Runtime, fixtureFolder)',
        fixture,
        'end)(Runtime, fixtureFolder)',
        'end, debug.traceback)',
        'fixtureFolder:Destroy()',
        "assert(ok, result)",
        "print('Packaged runtime Studio fixture passed:', result)",
        'return result',
    ])
    return '\n'.join(lines) + '\n'


def main():
    with tempfile.TemporaryDirectory(prefix='editrig-runtime-fixture-') as tmp:
        xml = Path(tmp) / 'runtime.rbxmx'
        subprocess.run([os.environ.get('ROJO_BIN', 'rojo'), 'build', 'runtime.project.json', '-o', str(xml)], cwd=ROOT, check=True, capture_output=True)
        items = ET.parse(xml).getroot().findall('./Item')
        if len(items) != 1:
            raise ValueError('runtime package must have exactly one root')
        program = render(items[0], FIXTURE.read_text())
    print(program, end='')


if __name__ == '__main__':
    main()
