# Spec · 显示名改为 openvideo

Status: ready-for-agent
日期：2026-08-13
来源：老板拍板（openvideo，全小写，与 openmy 同族）；GitHub Issues 已关，本 spec 落本地 tracker

## Problem Statement

老板已经不用 Replay 或 Stash 称呼这个应用。Dock、菜单栏、空窗口标题和空队列文案仍写 Stash，嘴上的名字和屏幕上的名字是两套。他要的名字是 openvideo：和 openmy 一家，全小写。

## Solution

用户看得见的产品名一律改成 `openvideo`。装进 /Applications 之后，Dock、Spotlight、菜单栏、窗口标题、空队列说明、画中画「回去」按钮、系统正在播放的兜底标题，全部是 openvideo。数据还在原地，入队命令还是现在这条，应用文件名仍是 Replay.app。

## User Stories

1. As 老板, I want Dock 上的名字是 openvideo, so that 和嘴里叫的一致
2. As 老板, I want 菜单栏应用名是 openvideo, so that 不会再看到 Stash 或 Replay
3. As 老板, I want Spotlight 搜 openvideo 能找到这个应用, so that 启动方式和 openmy 一样靠名字
4. As 老板, I want 没选中视频时窗口标题是 openvideo, so that 空窗口也叫对
5. As 老板, I want 空队列说明里的产品名是 openvideo, so that 第一眼文案就不撒谎
6. As 老板, I want 画中画回到主窗口的按钮写「回到 openvideo」, so that 辅助功能名称也不掉队
7. As 老板, I want 没有视频标题时「正在播放」兜底名是 openvideo, so that 控制中心不出现 Stash
8. As 老板, I want 界面任何地方不再出现 Stash, so that 改名是一次切干净，不是半套
9. As 老板, I want 改名后队列和已下载视频都还在, so that 不用重新入队
10. As 老板, I want 继续用现在的入队方式把链接丢进应用, so that agent 和手动粘贴都不改习惯
11. As 老板, I want 编译产物仍能按现有脚本打出可双击的应用, so that 改名不拆构建
12. As 老板, I want 装回 /Applications 后打开的就是新名字这一版, so that 不会点到旧的 Stash 实例

## Implementation Decisions

- 用户可见产品名固定为 `openvideo`（全小写，与 openmy 同形）。不要写成 OpenVideo 或 Open Video
- 只改显示名：Bundle Name 与 Display Name 都改为 openvideo
- Bundle ID 保持 `com.mg.replay`，禁止改。应用支持目录和影片目录继续用现有 Replay 路径，不做迁移
- 可执行文件名、包产物名、包管理器里的产品名、源码模块名、迁移逻辑用的应用目录名，全部保持 Replay。`open -a` 对 Replay.app 继续有效
- 源码里用户能看见的 Stash 文案改为 openvideo：空窗口标题兜底、空队列说明、画中画返回、正在播放兜底标题、对应辅助功能标签
- 源码标识符（应用结构体、迁移类型等）不改名为 OpenVideo
- README、Release 压缩包名、对外介绍不在本单改（发布线仍挂起）
- 编译沿用本机现有闸：macOS 27 上用 26 SDK 跑现有构建脚本，产物装进 /Applications。启动前礼貌退出已有同 Bundle ID 实例，避免打开旧包

## Testing Decisions

- 唯一 seam：运行中应用的用户可见产品名。不新增测试缝，不测内部标识符是否仍叫 Replay
- 好测试：只断言用户能看见或系统会展示的名字。构建出的 Info.plist 里 Display Name / Bundle Name 为 openvideo；Bundle ID 仍为 `com.mg.replay`；源码用户文案不再含 Stash；现有 `scripts/test.sh` 全绿
- 实机：退出旧实例后打开新包，Dock 与菜单栏为 openvideo，空队列文案含 openvideo 不含 Stash，已有队列条目仍在
- 先验：本仓 `scripts/test.sh` 是按文件编译的检查脚本，改名后必须照跑；T7 改名 Stash 时同一套构建与实机退出纪律

## Out of Scope

- 改 Bundle ID、数据目录、影片目录
- 把 Replay.app 文件名改成 openvideo.app
- README、GitHub Release、社交素材（发布线挂起）
- 图标
- replay-queue 技能、Hermes 回执文案、翻译管线仓库（那些线下次动时把产品名改成 openvideo）
- 功能、布局、主题

## Further Notes

- App Store 已有同名 AI 生视频应用 OpenVideo，另有开源 Open Video Downloader。本单是自用显示名，不解决上架撞名
- 本仓 GitHub Issues 已关闭，spec 放 `.scratch/openvideo-rename/spec.md`，状态 ready-for-agent
- 本机 yt-dlp 拉 YouTube 可能遇验证码，与本单无关，实机验收不依赖新下载
