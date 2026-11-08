#!/usr/bin/env python3
"""Generate a Studio Edit fixture from a freshly built plugin's runtime bundle."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def item_name(item):
    name = item.find('./Properties/string[@name="Name"]')
    if name is None or not name.text:
        raise ValueError('packaged item has no name')
    return name.text


def item_source(item):
    source = item.find('./Properties/string[@name="Source"]')
    if source is None:
        raise ValueError(f'{item_name(item)} has no source')
    return source.text or ''


def children_by_name(item):
    children = {}
    for child in item.findall('./Item'):
        name = item_name(child)
        if name in children:
            raise ValueError(f'duplicate packaged child: {name}')
        children[name] = child
    return children


def luau_string(value):
    equals = ''
    while ']' + equals + ']' in value:
        equals += '='
    # Luau drops the first newline after a long-string opener; add one so the
    # original source is preserved even if it begins with a newline.
    return '[' + equals + '[\n' + value + ']' + equals + ']'


def main():
    with tempfile.TemporaryDirectory(prefix='editrig-runtime-fixture-') as tmp:
        output = Path(tmp) / 'plugin.rbxmx'
        subprocess.run([os.environ.get('ROJO_BIN', 'rojo'), 'build', 'plugin.project.json', '-o', str(output)],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        roots = ET.parse(output).getroot().findall('./Item')
        if len(roots) != 1 or roots[0].get('class') != 'Script':
            raise ValueError('plugin package must contain one Script root')
        plugin = children_by_name(roots[0])
        bundle = plugin['RuntimeBundle']
        if bundle.get('class') != 'ModuleScript':
            raise ValueError('RuntimeBundle must be a ModuleScript')
        runtime_source = item_source(bundle)
        installer_source = item_source(plugin['RuntimeInstaller'])
        components = {name: item_source(item) for name, item in children_by_name(bundle).items()}
        test_source = (ROOT / 'tests/studio/RuntimePackage.integration.luau').read_text()
    lines = [
        '-- Generated from a freshly built plugin; runs a detached cloned runtime in Studio Edit.',
        "assert(game:GetService('RunService'):IsEdit(), 'Run this fixture in Studio Edit mode')",
        'local RuntimeInstaller=(function()\n' + installer_source + '\nend)()',
        'local RuntimeSource=' + luau_string(runtime_source),
        'local RuntimeComponents={}',
    ]
    for name, source in components.items():
        lines.append('RuntimeComponents[' + json.dumps(name) + ']=' + luau_string(source))
    lines += ['local result=(function()\n' + test_source + '\nend)()',
              "print('Built plugin runtime fixture passed:', result)", 'return result']
    # Construct everything before writing stdout: failed builds yield no script.
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
