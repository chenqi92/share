#!/usr/bin/env python3
"""Generate downloadable notes, including commits that did not use a PR."""
import json
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def notes(tag):
    generated = json.loads(run('gh', 'api', '--method', 'POST',
                               'repos/{owner}/{repo}/releases/generate-notes',
                               '-f', f'tag_name={tag}'))['body']
    try:
        previous = run('git', 'describe', '--tags', '--match', 'v[0-9]*', '--abbrev=0', f'{tag}^')
        revision_range = f'{previous}..{tag}'
    except subprocess.CalledProcessError:
        revision_range = tag
    commits = run('git', 'log', '--no-merges', '--format=- %s (%h)', revision_range)
    return f'''# MeshDrop {tag}

- Apple：[App Store](https://apps.apple.com/app/meshdrop/id6772689903)
- Windows：下载对应 x64 或 ARM64 的 ZIP，完整解压后运行 `MeshDrop.exe`。包含 .NET 和 Windows App SDK 运行时，无需另外安装。
- 校验：使用 `SHA256SUMS.txt` 检查下载文件。
- Apple 商店版本独立审核，版本以 App Store 页面为准。

{generated}

<details>
<summary>完整提交记录</summary>

{commits}

</details>
'''


if __name__ == '__main__':
    print(notes(sys.argv[1]))
