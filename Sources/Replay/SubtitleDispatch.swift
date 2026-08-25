enum SubtitleDispatchSurface: Equatable {
    case primary
    case fullscreen
    case floating
}

enum SubtitleDispatchPolicy {
    /// 字幕只发给当前实际承载画面的表面。
    static func destination(
        isFloatingActive: Bool,
        isFullscreen: Bool
    ) -> SubtitleDispatchSurface {
        if isFloatingActive { return .floating }
        if isFullscreen { return .fullscreen }
        return .primary
    }

    /// 非目标表面必须清空，避免主窗黑底残留字幕。
    static func shouldReceive(
        _ surface: SubtitleDispatchSurface,
        destination: SubtitleDispatchSurface
    ) -> Bool {
        surface == destination
    }

    /// 暂停态 seek 按目标时间立刻重发；播放器时钟可能尚未跳到目标点。
    static func presentationTime(afterSeekTo target: Double, playerTime: Double) -> Double {
        visibleTime(pendingSeekTime: target.isFinite ? target : nil, playerTime: playerTime)
    }

    /// seek 进行中继续按目标时间呈现，避免 SwiftUI 刷新用尚未更新的时钟写回旧句。
    static func visibleTime(pendingSeekTime: Double?, playerTime: Double) -> Double {
        if let pendingSeekTime, pendingSeekTime.isFinite { return max(0, pendingSeekTime) }
        if playerTime.isFinite { return max(0, playerTime) }
        return 0
    }
}
