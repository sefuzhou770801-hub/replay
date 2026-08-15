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

    /// 小于此位移仍当单击，避免微抖被认成排序。
    static let reorderDragThreshold: CGFloat = 12

    /// 本机文件还在才给出访达定位路径；缺文件或空路径不显示该菜单项。
    static func localFileToReveal(path: String?, exists: (String) -> Bool) -> String? {
        guard let path, !path.isEmpty, exists(path) else { return nil }
        return path
    }
}
