#!/usr/bin/env python3
"""Reject portable packages missing their native runtime dependencies."""
import argparse
import json
import struct
import zipfile


def validate(path, architecture):
    machine = {'x64': 0x8664, 'arm64': 0xaa64}[architecture.lower()]
    native = ['MeshDrop.exe', 'coreclr.dll', 'hostfxr.dll', 'Microsoft.ui.xaml.dll', 'libsodium.dll']
    required = native + ['MeshDrop.dll', 'resources.pri', 'MeshDrop.deps.json', 'MeshDrop.runtimeconfig.json']
    with zipfile.ZipFile(path) as archive:
        corrupt = archive.testzip()
        if corrupt:
            raise ValueError(f'Corrupt ZIP entry: {corrupt}')
        entries = {name.lower(): name for name in archive.namelist()}
        for name in required:
            if name.lower() not in entries:
                raise ValueError(f'Missing runtime file: {name}')
        for name in native:
            data = archive.read(entries[name.lower()])
            if len(data) < 64 or data[:2] != b'MZ':
                raise ValueError(f'Invalid executable: {name}')
            offset = struct.unpack_from('<I', data, 0x3c)[0]
            if offset + 6 > len(data) or data[offset:offset + 4] != b'PE\0\0':
                raise ValueError(f'Invalid PE header: {name}')
            if struct.unpack_from('<H', data, offset + 4)[0] != machine:
                raise ValueError(f'Wrong architecture: {name} (expected {architecture})')
        deps = json.loads(archive.read(entries['meshdrop.deps.json']))
        if not deps['runtimeTarget']['name'].endswith('/win-' + architecture.lower()):
            raise ValueError('Wrong dependency runtime target')
        config = json.loads(archive.read(entries['meshdrop.runtimeconfig.json']))['runtimeOptions']
        if not config.get('includedFrameworks') or 'framework' in config or 'frameworks' in config:
            raise ValueError('Package requires an external .NET runtime')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('package')
    parser.add_argument('architecture', choices=['x64', 'arm64', 'ARM64'])
    args = parser.parse_args()
    validate(args.package, args.architecture)
    print(f'Validated {args.architecture} runtime and ZIP: {args.package}')
