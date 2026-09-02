import AppKit
import SwiftUI

enum DigestBookChrome {
    static let minColumnWidth: CGFloat = 232
    static let minActionHit: CGFloat = 22
    static let highlightMarkWidth: CGFloat = 2
    static let annotationRadius: CGFloat = 8
    static let explainTitle = "解释"
    static let highlightTitle = "划线"
    static let tocPlaceholder = "生成目录"
    static let explainingLabel = "稍等…"
    static let commentPlaceholder = "写一句批语"
    static let toolbarSpacing: CGFloat = 8
    static let headerHorizontalPadding: CGFloat = 12
    static let actionReserveWidth: CGFloat = 112

    static func entryTitle(_ count: Int) -> String {
        "划线 \(count)"
    }
}

enum DigestHoverTracking {
    static let options: NSTrackingArea.Options = [
        .mouseEnteredAndExited,
        .activeAlways,
        .inVisibleRect
    ]
}

final class DigestHoverProbeView: NSView {
    var onHover: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
            self.hoverTrackingArea = nil
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: DigestHoverTracking.options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct DigestHoverMonitor: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> DigestHoverProbeView {
        let view = DigestHoverProbeView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: DigestHoverProbeView, context: Context) {
        nsView.onHover = onHover
    }
}

enum DigestBookHitKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

enum DigestBookWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
