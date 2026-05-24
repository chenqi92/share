# MeshDrop · 多端并行开发 Prompt 包

每端一份独立 prompt，可以同时投给多个 AI 并行开发 MeshDrop 的不同端 UI。

## 文件

| 文件 | 用途 |
| --- | --- |
| `COMMON.md` | 所有端 AI 必读的共享上下文（品牌 / tokens / 字体 / 组件 / mock 数据 / 11 条不能做）|
| `DESIGN_SPEC.md` | 更深的设计规范权威参考（细节版） |
| `01-macos.md` ~ `10-web.md` | 10 个端各自的特定指令 |
| `TESTING_AND_ACCEPTANCE.md` | 跨端测试矩阵 + 8 个互通用例 + 验收 checklist |
| `feed.sh` | 一键拼接 `COMMON.md + 端 prompt` 输出完整 prompt |

## 怎么用（推荐：feed.sh 一键拼）

```bash
cd prompts
./feed.sh macos | pbcopy        # macOS：直接拷到剪贴板
./feed.sh ios                   # 打印到 stdout
./feed.sh android > /tmp/p.md   # 写文件
./feed.sh                       # 不带参数：列出可用 platform
```

然后把剪贴板内容粘给 Claude / GPT / 任意 AI。

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
