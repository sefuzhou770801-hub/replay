import SwiftUI

struct SourceBrandMark: View {
    let sourceName: String

    var body: some View {
        switch QueueRowMeta.sourceMark(for: sourceName) {
        case .youtube:
            youtubeMark
        case .bilibili:
            bilibiliMark
        case .xiaohongshu:
            xiaohongshuMark
        case .x:
            xMark
        case .unknown:
            // 跟随所在行的前景色：正常行是次要灰，失败行随警示色一起变。
            Circle()
                .fill(.foreground)
                .opacity(0.7)
                .frame(width: 6, height: 6)
        }
    }

    // 队列元数据行只保留单色图标做来源识别，品牌色在灰阶列表里过于抢眼。
    private var youtubeMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(OpenMyChrome.muted)
            Image(systemName: "play.fill")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(OpenMyChrome.canvas)
                .offset(x: 0.4)
        }
        .frame(width: 14, height: 10)
    }

    private var bilibiliMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(OpenMyChrome.muted)
                .frame(width: 12, height: 8)
                .offset(y: 1)
            Path { path in
                path.move(to: CGPoint(x: 3.2, y: 2.4))
                path.addLine(to: CGPoint(x: 5.2, y: 0.4))
                path.move(to: CGPoint(x: 8.8, y: 2.4))
                path.addLine(to: CGPoint(x: 6.8, y: 0.4))
            }
            .stroke(OpenMyChrome.muted, lineWidth: 1.2)
            HStack(spacing: 2.2) {
                Capsule()
                    .fill(OpenMyChrome.canvas)
                    .frame(width: 1.6, height: 3.2)
                Capsule()
                    .fill(OpenMyChrome.canvas)
                    .frame(width: 1.6, height: 3.2)
            }
            .offset(y: 1.2)
        }
        .frame(width: 12, height: 12)
    }

    private var xiaohongshuMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(OpenMyChrome.muted)
            Path { path in
                path.move(to: CGPoint(x: 3.2, y: 2.4))
                path.addLine(to: CGPoint(x: 6, y: 3.4))
                path.addLine(to: CGPoint(x: 8.8, y: 2.4))
                path.addLine(to: CGPoint(x: 8.8, y: 9.4))
                path.addLine(to: CGPoint(x: 6, y: 8.4))
                path.addLine(to: CGPoint(x: 3.2, y: 9.4))
                path.closeSubpath()
                path.move(to: CGPoint(x: 6, y: 3.4))
                path.addLine(to: CGPoint(x: 6, y: 8.4))
            }
            .stroke(OpenMyChrome.canvas, lineWidth: 1)
        }
        .frame(width: 12, height: 12)
    }

    private var xMark: some View {
        Path { path in
            path.move(to: CGPoint(x: 1.4, y: 1.4))
            path.addLine(to: CGPoint(x: 10.6, y: 10.6))
            path.move(to: CGPoint(x: 10.6, y: 1.4))
            path.addLine(to: CGPoint(x: 1.4, y: 10.6))
        }
        .stroke(OpenMyChrome.muted, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        .frame(width: 12, height: 12)
    }
}
