import Foundation

enum DigestCopy {
    static let missingKeyHint =
        "还没填密钥。终端执行 defaults write com.mg.replay AnthropicAPIKey -string sk-…，或写入 GeminiAPIKey。"
    static let noSubtitles = "这段没有字幕"
    static let writeFailed = "这次没写成"
    static let emptyTitle = "暂无字幕"
    static let emptyLoadingDetail = "字幕仍在加载，或文件无法解析。"
    static let emptyUnavailableDetail = "当前视频没有可用字幕。"

    static func emptyDetail(hasSubtitleSource: Bool) -> String {
        hasSubtitleSource ? emptyLoadingDetail : emptyUnavailableDetail
    }

    static func showsBook(cueCount: Int, qaCount: Int) -> Bool {
        cueCount > 0 || qaCount > 0
    }

    static func showsDigestActions(cueCount: Int) -> Bool {
        cueCount > 0
    }
}
