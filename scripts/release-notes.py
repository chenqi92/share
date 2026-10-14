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

## 下载

| 平台 | 产物 / 安装方式 |
| --- | --- |
| Windows x64 / ARM64 | `windows-*.zip`：完整解压后运行 `MeshDrop.exe`；已包含 .NET、Windows App SDK 与本机加密库。 |
| macOS Intel / Apple Silicon | `macos-universal.zip`：解压后将 MeshDrop 拖入“应用程序”；Developer ID 签名并经 Apple 公证。也可通过 [App Store](https://apps.apple.com/app/meshdrop/id6772689903) 安装。 |
| iPhone / iPad / Apple Watch | [App Store](https://apps.apple.com/app/meshdrop/id6772689903)；Watch 随 iPhone App 分发，已审核版本以商店页面为准。 |
| Apple TV / 原生 visionOS | 此标签的 Release 构建已验证；原生商店版本尚未提交，源码位于 `apple/MeshDropTV`、`apple/MeshDropVision`。 |
| Android | `android.apk`：手机、平板直接安装；正式发布密钥签名。 |
| Wear OS | `wearos.apk`：手表端 Android companion。 |
| Linux 桌面 x64 / ARM64 | `linux-gui-*.deb`：Ubuntu 24.04+ 使用 `sudo apt install ./MeshDrop-*.deb`；其他发行版可用 `.tar.gz`，需 GTK 4.12+、libadwaita 1.5+、glibc 2.39+。 |
| Linux 终端 x64 / ARM64 | `linux-tui-*.tar.gz`：解压后运行 `./meshdrop-tui`；`--help` 查看发文本、传文件、发现设备和后台 daemon 命令，无需 GTK。Ubuntu 24.04+ / glibc 2.39+。 |
| Web | `web.zip`：构建好的静态站点，需连接已运行的桌面 Web Gateway；也可直接打开桌面端给出的网关地址。 |

Android / Wear OS 的 `.aab` 和 Windows 的 `*-store.msix` 是商店提交材料，普通用户安装使用 APK / ZIP。MSIX 未做侧载签名。

**兼容性：** Android、Wear OS、Linux、Web 组件仍为实验阶段；Android/Linux 的原生传输目前是 `0.1.0` 明文协议，不能直接连接 Apple/Windows 的 TLS 1.3 传输。Web 通过 Gateway 连接。此发布打包各组件在同一 Git 标签下的实现，并不表示所有组件已经具备相同的互通能力。

使用 `SHA256SUMS.txt` 校验文件；`release-manifest.json` 记录源码提交、打包流程提交、完整资产及 SHA-256。Apple 商店上架与本次 GitHub 发布独立审核。

{generated}

<details>
<summary>完整提交记录</summary>

{commits}

</details>
'''


if __name__ == '__main__':
    print(notes(sys.argv[1]))
