import Foundation

enum QueueRowMeta {
    enum SourceMark: Equatable, Hashable {
        case youtube
        case bilibili
        case xiaohongshu
        case x
        case unknown
    }

    static func sourceMark(for sourceName: String) -> SourceMark {
        switch sourceName {
        case "YouTube":
            return .youtube
        case "哔哩哔哩":
            return .bilibili
        case "小红书":
            return .xiaohongshu
        case "X":
            return .x
        default:
            return .unknown
        }
    }

    static func statusText(state: DownloadState, progressLabel: String) -> String {
        switch state {
        case .queued, .downloading, .failed:
            return progressLabel
        case .ready:
            return "已存到本地"
        }
    }
}
