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
            Circle()
                .fill(Color.secondary.opacity(0.7))
                .frame(width: 6, height: 6)
        }
    }

    private var youtubeMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color(red: 1, green: 0, blue: 0x33 / 255))
            Image(systemName: "play.fill")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 0.4)
        }
        .frame(width: 14, height: 10)
    }

    private var bilibiliMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(Color(red: 0xFB / 255, green: 0x72 / 255, blue: 0x99 / 255))
                .frame(width: 12, height: 8)
                .offset(y: 1)
            Path { path in
                path.move(to: CGPoint(x: 3.2, y: 2.4))
                path.addLine(to: CGPoint(x: 5.2, y: 0.4))
                path.move(to: CGPoint(x: 8.8, y: 2.4))
                path.addLine(to: CGPoint(x: 6.8, y: 0.4))
            }
            .stroke(Color(red: 0xFB / 255, green: 0x72 / 255, blue: 0x99 / 255), lineWidth: 1.2)
            HStack(spacing: 2.2) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 1.6, height: 3.2)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 1.6, height: 3.2)
            }
            .offset(y: 1.2)
        }
        .frame(width: 12, height: 12)
    }

    private var xiaohongshuMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(Color(red: 1, green: 0x24 / 255, blue: 0x42 / 255))
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
            .stroke(Color.white, lineWidth: 1)
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
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        .frame(width: 12, height: 12)
    }
}
