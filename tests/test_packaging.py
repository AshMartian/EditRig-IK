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
    'plugin.project.json': ('Script', 'EditRigIK', {'Config', 'ChainBuilder', 'DefinitionBuilder', 'GeneratedController', 'RigInspector'}),
    'runtime.project.json': ('ModuleScript', 'EditRigIKRuntime', {'Actor', 'ActorRig', 'ChainAdapter', 'ChainDefinition', 'JointAdapter', 'JointDrive', 'StepTrajectory', 'FootstepBehavior', 'FootstepChain', 'Ownership', 'Limits', 'Solver'}),
}
with tempfile.TemporaryDirectory(prefix='editrig-package-test-') as tmp:
    for project, (cls, name, children) in expected.items():
        output = Path(tmp) / (project + '.rbxmx')
        subprocess.run([rojo, 'build', project, '-o', str(output)], cwd=root, check=True, stdout=subprocess.DEVNULL)
        top = ET.parse(output).getroot().findall('./Item')
        assert len(top)==1 and top[0].get('class')==cls, f'{project} must have a top-level {cls}; got {[x.get("class") for x in top]}'
        def item_name(item):
            value=item.find('./Properties/string[@name="Name"]')
            return value.text if value is not None else None
        assert item_name(top[0])==name, f'{project} root has the wrong name'
        actual={item_name(x) for x in top[0].findall('./Item')}
        assert actual==children, f'{project} child modules differ: {actual ^ children}'
print('package structure tests passed')
