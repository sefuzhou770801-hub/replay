# 01 — 用户可见名改为 openvideo

**What to build:** 打开应用后，Dock、菜单栏、空窗口标题、空队列说明、画中画返回、系统正在播放的兜底标题全部是 `openvideo`（全小写）。已有队列和下载还在。入队方式不变。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] 构建产物的显示名是 openvideo，不是 Stash 或 Replay；Bundle ID 仍是原来的，队列数据还在
- [ ] 空窗口标题、空队列说明、画中画「回到 …」、没有视频标题时的正在播放兜底，都写 openvideo
- [ ] 用户能看见的界面不再出现 Stash
- [ ] 现有测试脚本退出码 0
- [ ] 礼貌退出旧实例后把新包装进 /Applications，Dock 与菜单栏是 openvideo，已有队列条目仍在
- [ ] 失败路径：若构建或安装失败，不覆盖 /Applications 里还能用的旧包，并说清停在哪一步
