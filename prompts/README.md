# MeshDrop · 多端并行开发 Prompt 包

每端一份独立 prompt，可以同时投给多个 AI 并行开发 MeshDrop 的不同端 UI。

这里保留 UI 开发和 Backend 接入两个阶段的模板，以及当时导出的完整提示词。
这些是开发任务资料，使用前请核对当前代码和 `protocol/` 中的实现说明。

## 文件

| 文件 | 用途 |
| --- | --- |
| `COMMON.md` | 所有端 AI 必读的共享上下文（品牌 / tokens / 字体 / 组件 / mock 数据 / 11 条不能做）|
| `DESIGN_SPEC.md` | 更深的设计规范权威参考（细节版） |
| `01-macos.md` ~ `10-web.md` | 10 个端各自的特定指令 |
| `TESTING_AND_ACCEPTANCE.md` | 跨端测试矩阵 + 8 个互通用例 + 验收 checklist |
| `B-COMMON.md`、`B-TESTING.md` | Backend 接入阶段的共享上下文与验收要求 |
| `B01-macos.md` ~ `B11-web.md` | 11 个端的 Backend 接入模板 |
| [`generated/backend/`](generated/backend/) | 从仓库根目录迁入的 11 份完整 Backend 提示词快照 |
| `feed.sh` | 将共享上下文、平台模板和验收要求拼接到标准输出，支持 UI / Backend 两种模式 |

## 完整 Backend 提示词

以下文件保留原始内容；修改模板后需要重新导出，快照不会自动同步。
文件中的仓库路径以仓库根目录为基准。

| 平台 | 完整提示词 |
| --- | --- |
| macOS | [macos.md](generated/backend/macos.md) |
| iOS / iPadOS | [ios.md](generated/backend/ios.md) |
| Android | [android.md](generated/backend/android.md) |
| Windows | [windows.md](generated/backend/windows.md) |
| Linux GUI | [linux-gui.md](generated/backend/linux-gui.md) |
| Linux TUI | [linux-tui.md](generated/backend/linux-tui.md) |
| tvOS | [tvos.md](generated/backend/tvos.md) |
| visionOS | [visionos.md](generated/backend/visionos.md) |
| Apple Watch | [watch.md](generated/backend/watch.md) |
| Wear OS | [wearos.md](generated/backend/wearos.md) |
| Web | [web.md](generated/backend/web.md) |

## 怎么用（推荐：feed.sh 一键拼）

```bash
cd prompts
./feed.sh macos | pbcopy        # macOS：直接拷到剪贴板
./feed.sh ios                   # 打印到 stdout
./feed.sh android > /tmp/p.md   # 写文件
./feed.sh backend-windows      # 打印完整 Backend 接入提示词
./feed.sh                       # 不带参数：列出可用 platform
```

然后把剪贴板内容粘给 Claude / GPT / 任意 AI。

需要保留导出文件时，统一放在 `generated/` 下，避免再次散落到仓库根目录：

```bash
mkdir -p generated/backend
./feed.sh backend-windows > generated/backend/windows.md
```

## 备选 1：手动 cat 拼接

```bash
cat COMMON.md 01-macos.md | pbcopy
```

## 备选 2：直接给 AI 两个文件

如果你的 AI 支持文件上传 / multi-message：
- 先给 `COMMON.md`
- 再给 `0X-<端>.md`
- 再给 `TESTING_AND_ACCEPTANCE.md`

## 各端建议分工

| 端 | 复杂度 | 适合 AI |
| --- | --- | --- |
| macOS | ★★★★ | 强（含 MenuBarExtra + drag overlay） |
| iOS/iPadOS Universal | ★★★★★ | 强（含 SizeClass 分支 + Share Extension + Live Activity） |
| Android | ★★★★ | 中（Compose 标准模式） |
| Windows | ★★★★ | 中（WinUI 3 标准，需注意避开 Fluent 默认蓝） |
| Linux GUI | ★★★ | 中（GTK4 较少 boilerplate，但需写 CSS） |
| Linux TUI | ★★ | 弱也行（ratatui 模式简单，但要做色彩 fallback） |
| tvOS | ★★★ | 中（焦点态 + 巨型字号设计为主） |
| visionOS | ★★★★★ | 强（空间布局 + 玻璃 + gaze/pinch 隐喻） |
| watch（Apple + Wear OS） | ★★★ | 中（双端共一份 prompt，注意 ≥ 10pt） |
| web | ★★★ | 中（React + Tailwind，dark by default） |

## 验收

每端 PR 必须满足：
- 截图清单全部附（详见各端 prompt"截图清单"段）
- 视觉对齐通过（详见 TESTING_AND_ACCEPTANCE.md C 节）
- build 一次过
- 无 MeshDrop / 至汝 / drop.mesh 残留

跨端互通用例（C1~C8）本轮**不要求过**（因为 UI-FIRST，没接 backend）。等所有
端 UI 都对齐后，下一轮再接 MeshDropEngine 跑互通。
