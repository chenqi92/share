#!/usr/bin/env python3
"""Validate a complete release and add assets without replacing published binaries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import shutil
import zipfile

METADATA = {'CHANGELOG.md', 'SHA256SUMS.txt', 'release-manifest.json'}


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def required_assets(tag):
    prefix = f'MeshDrop-{tag}'
    files = {f'{prefix}-macos-universal.zip', f'{prefix}-web.zip'}
    for architecture in ('x64', 'arm64'):
        files.update({f'{prefix}-windows-{architecture}.zip',
                      f'{prefix}-windows-{architecture}-store.msix',
                      f'{prefix}-linux-gui-{architecture}.deb',
                      f'{prefix}-linux-gui-{architecture}.tar.gz',
                      f'{prefix}-linux-tui-{architecture}.tar.gz'})
    for project in ('android', 'wearos'):
        files.update({f'{prefix}-{project}.apk', f'{prefix}-{project}.aab'})
    return files


def validate_assets(tag, directory):
    required = required_assets(tag)
    present = {path.name for path in directory.iterdir() if path.is_file()}
    missing = sorted(required - present)
    if missing:
        raise ValueError('Incomplete release: ' + ', '.join(missing))
    for name in required:
        path = directory / name
        if path.stat().st_size == 0:
            raise ValueError('Empty asset: ' + name)
        if path.suffix in ('.zip', '.apk', '.aab', '.msix'):
            with zipfile.ZipFile(path) as archive:
                bad = archive.testzip()
                if bad:
                    raise ValueError(f'{name}: corrupt archive member {bad}')
    return sorted(required)


def manifest(tag, directory, source_sha, tooling_sha):
    names = validate_assets(tag, directory)
    return {
        'release': tag,
        'source_commit': source_sha,
        'packaging_commit': tooling_sha,
        'apple_store': 'https://apps.apple.com/app/meshdrop/id6772689903',
        'compatibility': {
            'apple_windows': 'TLS 1.3 with mutual device authentication',
            'android_linux': 'Experimental 0.1.0 plaintext clients; incompatible with Apple/Windows TLS transport',
            'wearos': 'Experimental Android companion',
            'web': 'Gateway client; requires a running desktop gateway',
        },
        'assets': [{'name': name, 'size': (directory / name).stat().st_size,
                    'sha256': digest(directory / name)} for name in names],
    }


def existing_release(repo, tag):
    result = subprocess.run(['gh', 'api', f'repos/{repo}/releases/tags/{tag}'],
                            text=True, capture_output=True)
    if result.returncode:
        if 'HTTP 404' in result.stderr:
            return None
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


def download_existing(repo, tag, directory):
    release = existing_release(repo, tag)
    if release is None:
        return
    for asset in release['assets']:
        name = asset['name']
        if name not in required_assets(tag):
            continue
        path = directory / name
        checksum = asset.get('digest', '')
        if not path.exists():
            subprocess.run(['gh', 'release', 'download', tag, '--repo', repo,
                            '--pattern', name, '--dir', str(directory)], check=True)
        if not checksum.startswith('sha256:') or digest(path) != checksum.removeprefix('sha256:'):
            raise ValueError('Refusing to replace or trust a mismatched published asset: ' + name)


def reuse_published(repo, tag, directory):
    release = existing_release(repo, tag)
    if release is None:
        return
    for asset in release['assets']:
        name = asset['name']
        if name not in required_assets(tag) or not (directory / name).is_file():
            continue
        with tempfile.TemporaryDirectory() as temporary:
            subprocess.run(['gh', 'release', 'download', tag, '--repo', repo,
                            '--pattern', name, '--dir', temporary], check=True)
            downloaded = Path(temporary) / name
            if asset.get('digest') != 'sha256:' + digest(downloaded):
                raise ValueError('Published download checksum mismatch: ' + name)
            shutil.copyfile(downloaded, directory / name)


def publish(repo, tag, directory):
    validate_assets(tag, directory)
    release = existing_release(repo, tag)
    if release is None:
        subprocess.run(['gh', 'release', 'create', tag, '--repo', repo, '--verify-tag',
                        '--draft', '--title', f'MeshDrop {tag}',
                        '--notes-file', str(directory / 'CHANGELOG.md')], check=True)
        release = existing_release(repo, tag)
    existing = {a['name']: a for a in release['assets']}
    # Check every collision before performing the first upload.
    for path in directory.iterdir():
        if path.name in existing and path.name not in METADATA:
            if existing[path.name].get('digest') != 'sha256:' + digest(path):
                raise ValueError('Published binary is immutable: ' + path.name)
    for path in sorted(directory.iterdir()):
        if path.name not in required_assets(tag) | METADATA:
            continue
        if path.name in existing and path.name not in METADATA:
            continue
        command = ['gh', 'release', 'upload', tag, str(path), '--repo', repo]
        if path.name in METADATA:
            command.append('--clobber')
        subprocess.run(command, check=True)
    command = ['gh', 'release', 'edit', tag, '--repo', repo, '--draft=false',
               '--notes-file', str(directory / 'CHANGELOG.md')]
    command += ['--prerelease', '--latest=false'] if '-' in tag else ['--latest']
    subprocess.run(command, check=True)
    remote = existing_release(repo, tag)
    for asset in remote['assets']:
        path = directory / asset['name']
        if path.is_file() and asset.get('digest') != 'sha256:' + digest(path):
            raise ValueError('Remote checksum mismatch: ' + asset['name'])
    if required_assets(tag) - {a['name'] for a in remote['assets']}:
        raise ValueError('Remote release is incomplete')
    print(remote['html_url'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['collect', 'reuse', 'prepare', 'publish'])
    parser.add_argument('tag')
    parser.add_argument('--directory', type=Path, default=Path('release-assets'))
    parser.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY', 'chenqi92/share'))
    args = parser.parse_args()
    args.directory.mkdir(parents=True, exist_ok=True)
    try:
        if args.command == 'collect':
            download_existing(args.repo, args.tag, args.directory)
        elif args.command == 'reuse':
            reuse_published(args.repo, args.tag, args.directory)
        elif args.command == 'prepare':
            data = manifest(args.tag, args.directory, run('git', 'rev-parse', args.tag + '^{commit}'),
                            os.environ.get('GITHUB_SHA') or run('git', 'rev-parse', 'HEAD'))
            (args.directory / 'release-manifest.json').write_text(json.dumps(data, indent=2) + '\n')
            names = sorted(required_assets(args.tag) | {'CHANGELOG.md', 'release-manifest.json'})
            checksums = ''.join(f'{digest(args.directory / name)}  {name}\n' for name in names)
            (args.directory / 'SHA256SUMS.txt').write_text(checksums)
        else:
            publish(args.repo, args.tag, args.directory)
    except (ValueError, RuntimeError) as error:
        sys.exit(str(error))
