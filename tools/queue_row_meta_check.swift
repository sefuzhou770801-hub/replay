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

        print("queue_row_meta_check=passed")
    }
}
