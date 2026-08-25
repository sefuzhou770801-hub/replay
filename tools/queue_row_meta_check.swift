import Foundation

@main
struct QueueRowMetaCheck {
    static func main() {
        precondition(QueueRowMeta.sourceMark(for: "YouTube") == .youtube)
        precondition(QueueRowMeta.sourceMark(for: "哔哩哔哩") == .bilibili)
        precondition(QueueRowMeta.sourceMark(for: "小红书") == .xiaohongshu)
        precondition(QueueRowMeta.sourceMark(for: "X") == .x)
        precondition(QueueRowMeta.sourceMark(for: "Vimeo") == .unknown)
        precondition(QueueRowMeta.sourceMark(for: "视频") == .unknown)

        let knownMarks: [QueueRowMeta.SourceMark] = [
            QueueRowMeta.sourceMark(for: "YouTube"),
            QueueRowMeta.sourceMark(for: "哔哩哔哩"),
            QueueRowMeta.sourceMark(for: "小红书"),
            QueueRowMeta.sourceMark(for: "X"),
        ]
        precondition(Set(knownMarks).count == 4, "四个平台简标种类必须互不相同")

        let readyWithProgress = QueueRowMeta.statusText(state: .ready, progressLabel: "已下载")
        precondition(
            !readyWithProgress.contains("续播"),
            "就绪态不得出现续播文案，实际：\(readyWithProgress)"
        )
        precondition(readyWithProgress == "已存到本地")
        precondition(QueueRowMeta.statusText(state: .ready, progressLabel: "续播 99:28") == "已存到本地")

        precondition(QueueRowMeta.statusText(state: .queued, progressLabel: "排队中") == "排队中")
        precondition(QueueRowMeta.statusText(state: .queued, progressLabel: "低电量模式已暂停") == "低电量模式已暂停")
        precondition(QueueRowMeta.statusText(state: .queued, progressLabel: "等待网络连接") == "等待网络连接")
        precondition(QueueRowMeta.statusText(state: .queued, progressLabel: "等待下载槽位") == "等待下载槽位")
        precondition(QueueRowMeta.statusText(state: .downloading, progressLabel: "下载中…") == "下载中…")
        precondition(QueueRowMeta.statusText(state: .failed, progressLabel: "重试 3 次后失败") == "重试 3 次后失败")

        precondition(QueueRowMeta.localFileToReveal(path: nil, exists: { _ in true }) == nil)
        precondition(QueueRowMeta.localFileToReveal(path: "", exists: { _ in true }) == nil)
        precondition(QueueRowMeta.localFileToReveal(path: "/tmp/gone.mp4", exists: { _ in false }) == nil)
        precondition(QueueRowMeta.localFileToReveal(path: "/tmp/ready.mp4", exists: { $0 == "/tmp/ready.mp4" }) == "/tmp/ready.mp4")
        precondition(
            QueueRowMeta.reorderDragThreshold >= 10,
            "拖拽阈值过小会把单击认成排序"
        )

        let states: [DownloadState] = [.queued, .downloading, .ready, .failed]
        for isWatched in [false, true] {
            for state in states {
                for canReveal in [false, true] {
                    let items = QueueRowMeta.contextMenuItems(
                        isWatched: isWatched,
                        state: state,
                        canRevealLocalFile: canReveal
                    )
                    precondition(
                        items.contains(.rename),
                        "任意队列行右键菜单都必须有重命名：watched=\(isWatched) state=\(state) reveal=\(canReveal)"
                    )
                    precondition(
                        QueueRowMeta.visibleTitle(for: .rename, isWatched: isWatched) == "重命名"
                    )
                }
            }
        }

        let failedMenu = QueueRowMeta.contextMenuItems(
            isWatched: false,
            state: .failed,
            canRevealLocalFile: false
        )
        precondition(failedMenu == [
            .toggleWatched, .rename, .retryDownload, .openOriginal, .divider, .delete
        ])

        let readyWithFile = QueueRowMeta.contextMenuItems(
            isWatched: true,
            state: .ready,
            canRevealLocalFile: true
        )
        precondition(readyWithFile == [
            .toggleWatched, .rename, .openOriginal, .revealInFinder, .divider, .delete
        ])
        precondition(QueueRowMeta.visibleTitle(for: .toggleWatched, isWatched: true) == "移回队列")
        precondition(QueueRowMeta.visibleTitle(for: .toggleWatched, isWatched: false) == "标记已看")

        precondition(QueueRowMeta.shouldBeginTitleEditing(isSelected: true, clickCount: 2))
        precondition(QueueRowMeta.shouldBeginTitleEditing(isSelected: true, clickCount: 3))
        precondition(!QueueRowMeta.shouldBeginTitleEditing(isSelected: true, clickCount: 1))
        precondition(!QueueRowMeta.shouldBeginTitleEditing(isSelected: false, clickCount: 2))
        precondition(!QueueRowMeta.shouldBeginTitleEditing(isSelected: false, clickCount: 1))

        precondition(
            QueueRowMeta.titleEditCommit(reason: .submit, draft: "  新标题  ") == .save("新标题")
        )
        precondition(
            QueueRowMeta.titleEditCommit(reason: .submit, draft: "   ") == .discard,
            "回车空名不得保存"
        )
        precondition(
            QueueRowMeta.titleEditCommit(reason: .escape, draft: "改过的名字") == .discard,
            "Esc 必须恢复原名，不保存"
        )
        precondition(
            QueueRowMeta.titleEditCommit(reason: .escape, draft: "  新标题  ") == .discard
        )
        precondition(
            QueueRowMeta.titleEditCommit(reason: .focusLost, draft: "  点走保存  ") == .save("点走保存")
        )
        precondition(
            QueueRowMeta.titleEditCommit(reason: .focusLost, draft: " \n ") == .discard
        )

        print("queue_row_meta_check=passed")
    }
}
