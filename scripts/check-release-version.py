#!/usr/bin/env python3
"""Check release tags against the versions embedded in distributed clients."""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def validate(tag: str, root: Path = ROOT) -> str:
    match = re.fullmatch(r"v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))(?:-(?:alpha|beta|rc)\.[1-9][0-9]*)?", tag)
    if not match:
        raise ValueError("Use vMAJOR.MINOR.PATCH, optionally followed by -alpha.N, -beta.N or -rc.N")
    version = match[1]
    if any(int(part) > 65535 for part in version.split('.')) or version.startswith('0.'):
        raise ValueError("Release version must fit MSIX version fields and have major >= 1")
    actual = {
        'VERSION': (root / 'VERSION').read_text().strip(),
        'Windows': ET.parse(root / 'windows/MeshDrop/MeshDrop.csproj').findtext('./PropertyGroup/Version'),
        'MSIX': ET.parse(root / 'windows/MeshDrop/Package.appxmanifest').find('{*}Identity').get('Version'),
    }
    for app in ['MeshDropMac', 'MeshDropiOS']:
        source = (root / f'apple/{app}/project.yml').read_text()
        actual[app] = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', source)[1]
    for name, value in actual.items():
        expected = version + '.0' if name == 'MSIX' else version
        if value != expected:
            raise ValueError(f'{name}: expected {expected}, found {value}')
    return version


if __name__ == '__main__':
    try:
        print(validate(sys.argv[1]))
    except (ValueError, IndexError) as error:
        sys.exit(str(error))
