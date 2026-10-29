# FreeCell · 空当接龙

使用 SwiftUI / AppKit 开发的 macOS 原生空当接龙。离线运行，无第三方依赖。牌桌和弹窗采用图标界面，仅保留牌面与必要数字；悬停可查看说明。

## 运行

通过 Homebrew 安装（macOS 13+，Apple Silicon / Intel）：

```sh
brew tap laixintao/tap
brew install --cask freecell
```

更新：`brew update && brew upgrade --cask laixintao/tap/freecell`。
卸载：`brew uninstall --cask laixintao/tap/freecell`，默认保留存档。

双击 `dist/FreeCell.app`。也可以将应用拖入「应用程序」文件夹。

从源码构建需要 macOS 13 或更高版本、Swift 6 或更高版本的 Xcode / Command Line Tools：

```sh
./scripts/build-app.sh
open dist/FreeCell.app
```

本地构建脚本生成当前 Mac 架构的应用，并进行 ad-hoc 签名。GitHub Releases 分别提供 Apple Silicon 和 Intel 的 DMG / ZIP 安装包、SHA256SUMS 和构建来源证明。当前版本没有 Apple Developer ID 签名及公证；若 macOS 阻止首次打开，请按 [Apple 官方说明](https://support.apple.com/en-us/102445)在「系统设置 → 隐私与安全」允许打开。

也可用 Xcode 打开 `Package.swift`，选择 FreeCell 并运行。命令行开发运行：`swift run FreeCell`。

## 玩法

- 将 52 张牌按花色从 A 到 K 移入右上方收牌区。
- 下方 8 列按红黑交替、点数递减接龙；空列可放任意牌。
- 左上方 4 个空当各放 1 张牌。
- 连续牌组移动容量为 `(空当数 + 1) × 2^可借用空列数`；目标空列不计入容量。
- 拖动移牌，或点选牌后点击目标。双击单牌优先收牌，否则移入空当。
- 支持撤销、重做、合法走法提示、安全收牌、重新开始同一局，以及编号选局。
- 编号采用 Microsoft FreeCell 的发牌算法，随机牌局来自 1–32000。提示只建议合法走法，不是求解器；不保证所有编号有解。
- 右下角的闪光牌组图标可开启移动后自动安全收牌；自动收牌与触发它的移牌合为一次撤销。

| 快捷键 | 操作 |
| --- | --- |
| ⌘N | 新牌局 / 指定编号 |
| ⌘Z / ⇧⌘Z | 撤销 / 重做 |
| ⌘I | 提示 |
| ⇧⌘A | 安全收牌 |
| ⇧⌘R | 重开本局 |
| Esc | 取消选择 |
| ⌘? | 玩法帮助 |

每次操作后自动保存，计时每 5 秒保存一次；退出和切换应用时也保存。未开始、应用失焦、显示玩法或新局对话框、获胜时暂停计时。存档在 `~/Library/Application Support/FreeCell/game.json`，包含局面、撤销 / 重做历史、编号和计时。自动安全收牌开关默认关闭，仅对当前运行生效。无法读取的存档会退回到新牌局。

## 验证

```sh
./scripts/test.sh
./scripts/build-app.sh
open -n dist/FreeCell.app -W --args --smoke-test /tmp/freecell-smoke --exit-after-test
cat /tmp/freecell-smoke/result.txt
```

规则测试涵盖经典编号发牌、红黑递减、空当占用、收牌顺序、牌组容量、非法移动不改变状态、安全收牌、撤销 / 重做、胜利、存档损坏，以及多局随机合法操作的 52 张牌守恒。原生冒烟检查会向真实窗口发送鼠标和菜单快捷键事件，验证单牌 / 牌组拖放、胜利界面和弹窗。它使用独立存档，不触碰日常游戏进度，并输出窗口截图 `native-window.png`。

## 代码

- `Sources/FreeCellCore`：独立规则引擎、牌局历史、原子存档。
- `Sources/FreeCell`：原生窗口、牌桌、拖动交互、菜单、对话框、运行时验证。
- `Tests/FreeCellCoreTests`：Swift Testing 测试。
- `scripts/build-app.sh`：构建、图标生成、打包及本地签名。

## 发布

安装版本工具：`pipx install bump2version==1.0.1`，或在虚拟环境中安装 `requirements-release.txt`。
日常从已提交且干净的 `main` 发布：

```sh
git switch main
git pull --ff-only
make release
```

`make release` 检查远程历史和 tag 冲突，调用 `bumpversion` 递增 patch，同步 `VERSION`、`.bumpversion.cfg` 及应用的两个版本字段，生成提交和 annotated tag，然后原子推送分支与 tag。指定版本可用 `make release VERSION=1.1.0`。推送失败时保留本地提交和 tag，并打印重试命令；不要再次 bump 或移动已发布 tag。

也可直接使用 bumpversion：

```sh
bumpversion patch  # 或 minor / major；自动 commit + tag
git push --atomic origin main --follow-tags
```

推送 `v*` tag 后，GitHub Actions 自动执行版本检查、双架构测试与构建、DMG / ZIP 校验、SHA256SUMS 汇总、来源证明和 Release 发布。只发布经过测试的同一份构建产物；失败的草稿可重试，已公开的 Release 不覆盖。

安装包遵循 [tap 发布规范](https://github.com/laixintao/homebrew-tap/blob/main/docs/RELEASE_STANDARD.md)：`FreeCell-<version>-macos-<arm64|x86_64>.dmg` 与 `.zip`。tap 的 [Update casks](https://github.com/laixintao/homebrew-tap/actions/workflows/update-casks.yml) 每 6 小时校验上游 Release 并自动更新，也可手动触发立即同步；无需跨仓库 Secret。

`make test` 同时运行游戏规则测试和隔离的发布流程测试；`make ci-package` 测试、构建并验证本机架构安装包。正常 CI 与 tag 发布复用 `.github/workflows/build.yml`。
