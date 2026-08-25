import Foundation

@main
struct SubtitleDispatchCheck {
    static func main() {
        let primary = SubtitleDispatchPolicy.destination(
            isFloatingActive: false,
            isFullscreen: false
        )
        precondition(primary == .primary)
        precondition(SubtitleDispatchPolicy.shouldReceive(.primary, destination: primary))
        precondition(!SubtitleDispatchPolicy.shouldReceive(.fullscreen, destination: primary))
        precondition(!SubtitleDispatchPolicy.shouldReceive(.floating, destination: primary))

        let floating = SubtitleDispatchPolicy.destination(
            isFloatingActive: true,
            isFullscreen: false
        )
        precondition(floating == .floating)
        precondition(
            !SubtitleDispatchPolicy.shouldReceive(.primary, destination: floating),
            "悬浮期间主窗不得接收字幕更新"
        )
        precondition(
            !SubtitleDispatchPolicy.shouldReceive(.fullscreen, destination: floating),
            "悬浮期间全屏面也不得残留字幕"
        )
        precondition(SubtitleDispatchPolicy.shouldReceive(.floating, destination: floating))

        let restored = SubtitleDispatchPolicy.destination(
            isFloatingActive: false,
            isFullscreen: false
        )
        precondition(restored == .primary)
        precondition(
            SubtitleDispatchPolicy.shouldReceive(.primary, destination: restored),
            "点悬浮窗回到主窗后，主窗必须重新接收字幕"
        )
        precondition(
            !SubtitleDispatchPolicy.shouldReceive(.floating, destination: restored),
            "回到主窗后悬浮面不得继续接收字幕"
        )

        let fullscreen = SubtitleDispatchPolicy.destination(
            isFloatingActive: false,
            isFullscreen: true
        )
        precondition(fullscreen == .fullscreen)
        precondition(!SubtitleDispatchPolicy.shouldReceive(.primary, destination: fullscreen))
        precondition(SubtitleDispatchPolicy.shouldReceive(.fullscreen, destination: fullscreen))
        precondition(!SubtitleDispatchPolicy.shouldReceive(.floating, destination: fullscreen))

        let floatingOverFullscreen = SubtitleDispatchPolicy.destination(
            isFloatingActive: true,
            isFullscreen: true
        )
        precondition(
            floatingOverFullscreen == .floating,
            "切走应用时画面在悬浮窗，即使此前处于全屏"
        )
        precondition(
            !SubtitleDispatchPolicy.shouldReceive(.fullscreen, destination: floatingOverFullscreen)
        )

        precondition(
            SubtitleDispatchPolicy.presentationTime(afterSeekTo: 42, playerTime: 3) == 42,
            "暂停态 seek 必须按目标时间立刻重发，不得沿用尚未更新的播放器时钟"
        )
        precondition(SubtitleDispatchPolicy.presentationTime(afterSeekTo: 0, playerTime: 10) == 0)
        precondition(
            SubtitleDispatchPolicy.presentationTime(afterSeekTo: .nan, playerTime: 8) == 8,
            "目标时间无效时回落到播放器时钟"
        )
        precondition(SubtitleDispatchPolicy.presentationTime(afterSeekTo: -5, playerTime: 1) == 0)
        precondition(
            SubtitleDispatchPolicy.presentationTime(afterSeekTo: .nan, playerTime: .nan) == 0
        )
        precondition(
            SubtitleDispatchPolicy.visibleTime(pendingSeekTime: 42, playerTime: 3) == 42,
            "seek 尚未完成时必须继续按目标时间呈现，避免 SwiftUI 刷新把字幕写回旧句"
        )
        precondition(SubtitleDispatchPolicy.visibleTime(pendingSeekTime: nil, playerTime: 3) == 3)
        precondition(SubtitleDispatchPolicy.visibleTime(pendingSeekTime: .nan, playerTime: 3) == 3)

        print("subtitle_dispatch_check=passed")
    }
}
