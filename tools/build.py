#!/usr/bin/env python3
"""Validate and atomically stage the current experimental plugin artifact."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
source = sorted([ROOT / 'plugin.project.json', ROOT / 'runtime.project.json', *ROOT.glob('src/**/*.luau'), *ROOT.glob('examples/**/*.luau'), *ROOT.glob('tests/**/*.luau'), *ROOT.glob('tests/**/*.py'), ROOT / 'tools/build.py'])
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
fingerprint = hashlib.sha256()
for path in source:
    fingerprint.update(str(path.relative_to(ROOT)).encode() + b'\0' + bytes.fromhex(sha(path)))
luau = os.environ.get('LUAU_BIN', 'luau')
compiler = os.environ.get('LUAU_COMPILE_BIN', 'luau-compile')
rojo = os.environ.get('ROJO_BIN', 'rojo')
commands = [['python3', 'tests/test_packaging.py']]
commands += [[luau, str(path.relative_to(ROOT))] for path in sorted(ROOT.glob('tests/*.luau'))]
commands += [[compiler, str(path.relative_to(ROOT))] for path in sorted([*ROOT.glob('src/**/*.luau'), *ROOT.glob('examples/**/*.luau'), *ROOT.glob('tests/studio/*.luau')])]
BUILD.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='.stage-', dir=BUILD) as temp:
    stage = Path(temp)
    for command in commands:
        print('+', ' '.join(command), flush=True)
        subprocess.run(command, cwd=ROOT, check=True, stdout=subprocess.DEVNULL if command[0] == compiler else None)
    artifacts = {}
    builds = []
    for project, filename in [('plugin.project.json', 'EditRigIK.rbxm'), ('runtime.project.json', 'EditRigIKRuntime.rbxm')]:
        artifact = stage / filename
        build = [rojo, 'build', project, '-o', str(artifact)]
        print('+', ' '.join(build), flush=True)
        subprocess.run(build, cwd=ROOT, check=True)
        if not artifact.read_bytes().startswith(b'<roblox!'):
            raise RuntimeError('invalid Roblox binary header: ' + filename)
        artifacts[filename] = sha(artifact)
        builds.append([rojo, 'build', project])
    version = subprocess.check_output([rojo, '--version'], text=True).strip()
    manifest = {'source_sha256':fingerprint.hexdigest(), 'source_files':[str(p.relative_to(ROOT)) for p in source], 'rojo':version, 'tool_sha256': {name: sha(Path(shutil.which(exe) or exe)) for name, exe in [('luau', luau), ('luau_compile', compiler), ('rojo', rojo)]}, 'luau_release':'0.746 expected; verify downloaded executable against trusted release', 'commands':commands + builds, 'result':'passed', 'artifacts_sha256':artifacts, 'studio_validation':'not performed'}
    (stage / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    current, previous = BUILD / 'current', BUILD / '.previous'
    if previous.exists():
        raise RuntimeError('previous build recovery directory exists; inspect it before rebuilding')
    if current.exists(): current.rename(previous)
    try:
        stage.rename(current)
    except BaseException:
        if previous.exists(): previous.rename(current)
        raise
    if previous.exists(): shutil.rmtree(previous)
print('Validated build/current; Studio verification remains outstanding.')
