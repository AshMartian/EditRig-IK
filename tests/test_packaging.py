#!/usr/bin/env python3
"""Verify the root instances Studio receives from each Rojo project."""
from pathlib import Path
import os
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
rojo = os.environ.get('ROJO_BIN', 'rojo')
expected = {
    'plugin.project.json': ('Script', 'EditRigIK', {'Config', 'ChainBuilder', 'ChainDiscovery', 'DefinitionBuilder', 'GeneratedController', 'RigInspector', 'AxisGizmo', 'LimitGeometry', 'PreviewSession', 'PreviewSolver', 'PreviewLimits', 'PreviewChainAdapter', 'PreviewChainDefinition', 'RuntimeInstaller', 'RuntimeBundle'}),
    'runtime.project.json': ('ModuleScript', 'EditRigIKRuntime', {'Actor', 'ActorRig', 'ChainAdapter', 'ChainDefinition', 'JointAdapter', 'JointDrive', 'InputBindings', 'StepTrajectory', 'FootstepBehavior', 'FootstepChain', 'Ownership', 'Limits', 'Solver'}),
}
with tempfile.TemporaryDirectory(prefix='editrig-package-test-') as tmp:
    roots = {}
    for project, (cls, name, children) in expected.items():
        output = Path(tmp) / (project + '.rbxmx')
        subprocess.run([rojo, 'build', project, '-o', str(output)], cwd=root, check=True, stdout=subprocess.DEVNULL)
        top = ET.parse(output).getroot().findall('./Item')
        assert len(top)==1 and top[0].get('class')==cls, f'{project} must have a top-level {cls}; got {[x.get("class") for x in top]}'
        roots[project]=top[0]
        def item_name(item):
            value=item.find('./Properties/string[@name="Name"]')
            return value.text if value is not None else None
        assert item_name(top[0])==name, f'{project} root has the wrong name'
        actual={item_name(x) for x in top[0].findall('./Item')}
        assert actual==children, f'{project} child modules differ: {actual ^ children}'
    plugin=roots['plugin.project.json']
    runtime=roots['runtime.project.json']
    bundle=next(x for x in plugin.findall('./Item') if item_name(x)=='RuntimeBundle')
    assert bundle.get('class')=='ModuleScript'
    def source(item):
        value=item.find('./Properties/string[@name="Source"]')
        assert value is not None, f'{item_name(item)} source missing'
        return value.text or ''
    assert source(bundle)==source(runtime), 'bundled runtime root differs from standalone package'
    bundled_children={item_name(x):x for x in bundle.findall('./Item')}
    runtime_children={item_name(x):x for x in runtime.findall('./Item')}
    assert bundled_children.keys()==runtime_children.keys(), 'bundled runtime components differ'
    for name, item in runtime_children.items():
        assert bundled_children[name].get('class')==item.get('class') and source(bundled_children[name])==source(item), f'bundled {name} differs from standalone package'
print('package structure tests passed')
