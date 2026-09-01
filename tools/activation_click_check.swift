import AppKit
import SwiftUI

@main
struct ActivationClickCheck {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let shield = ForegroundActivationClickShield()
        shield.attach(to: window)

        shield.arm()
        precondition(shield.isArmed)
        precondition(shield.hitTest(NSPoint(x: 20, y: 20)) === shield)
        precondition(shield.acceptsFirstMouse(for: nil))

        shield.disarm()
        precondition(!shield.isArmed)
        precondition(shield.hitTest(NSPoint(x: 20, y: 20)) == nil)

        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        precondition(shield.isArmed)

        NotificationCenter.default.post(
            name: NSApplication.didBecomeActiveNotification,
            object: NSApp
        )
        // The first activating click must remain shielded for the rest of its
        // dispatch turn. The app disarms asynchronously on the next turn.
        precondition(shield.isArmed)
        shield.disarm()

        shield.detach()
        precondition(shield.superview == nil)

        precondition(DetailHeaderMetrics.leadingPadding(sidebarCollapsed: true) == 154)
        precondition(
            DetailHeaderMetrics.leadingPadding(sidebarCollapsed: false) >= 52,
            "展开左侧栏后系统侧栏钮仍在标题左缘，14 点会叠字"
        )
        precondition(
            DetailHeaderMetrics.leadingPadding(sidebarCollapsed: true)
                > DetailHeaderMetrics.leadingPadding(sidebarCollapsed: false)
        )

        assertPaneHeaderIconButtons()

        print("activation_click_check=passed")
    }

    @MainActor
    private static func assertPaneHeaderIconButtons() {
        precondition(
            PaneHeaderIconMetrics.minHitSize >= 24,
            "图标按钮命中区不得小于 24 点，实际 \(PaneHeaderIconMetrics.minHitSize)"
        )
        precondition(
            PaneHeaderIconMetrics.spacing > 8,
            "三个图标按钮间距必须比原来的 8 点更开，实际 \(PaneHeaderIconMetrics.spacing)"
        )
        precondition(
            PaneHeaderIconMetrics.hoverDelay == 0,
            "悬浮说明必须立即出现，不得走系统 .help 延迟"
        )

        var taps = 0
        let button = Button(action: { taps += 1 }) {
            PaneHeaderIconLabel(
                systemImage: "arrow.up.forward",
                title: "打开原网页",
                expanded: false
            )
        }
        .watchGlassButton()
        let host = NSHostingView(rootView: button)
        let collapsedSize = host.fittingSize
        precondition(
            collapsedSize.width >= PaneHeaderIconMetrics.minHitSize
                && collapsedSize.height >= PaneHeaderIconMetrics.minHitSize,
            "未展开时命中区必须 ≥24×24，实际 \(collapsedSize)"
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: collapsedSize)
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()

        click(window, in: host, at: NSPoint(x: 1, y: host.bounds.height - 1))
        precondition(taps == 1, "点图标左上边缘必须命中，实际 taps=\(taps)")
        click(window, in: host, at: NSPoint(x: host.bounds.width - 1, y: 1))
        precondition(taps == 2, "点图标右下边缘必须命中，实际 taps=\(taps)")

        let expanded = NSHostingView(
            rootView: PaneHeaderIconLabel(
                systemImage: "arrow.up.forward",
                title: "打开原网页",
                expanded: true
            )
        )
        let expandedSize = expanded.fittingSize
        precondition(
            expandedSize.width > collapsedSize.width,
            "悬停展开后必须露出中文说明，展开宽 \(expandedSize.width) 收起宽 \(collapsedSize.width)"
        )
        precondition(
            expandedSize.width >= collapsedSize.width + 40,
            "展开后中文『打开原网页』必须占到宽度，展开 \(expandedSize.width) 收起 \(collapsedSize.width)"
        )
        let collapsedLabel = NSHostingView(
            rootView: PaneHeaderIconLabel(
                systemImage: "arrow.up.forward",
                title: "打开原网页",
                expanded: false
            )
        )
        precondition(
            abs(collapsedLabel.fittingSize.width - collapsedSize.width) < 1,
            "收起后宽度必须回到图标命中区，实际 \(collapsedLabel.fittingSize)"
        )

        window.close()
    }

    private static func click(_ window: NSWindow, in view: NSView, at local: NSPoint) {
        let location = view.convert(local, to: nil)
        func event(_ type: NSEvent.EventType) -> NSEvent {
            NSEvent.mouseEvent(
                with: type,
                location: location,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: Int.random(in: 1...10_000),
                clickCount: 1,
                pressure: 1
            )!
        }
        window.sendEvent(event(.leftMouseDown))
        window.sendEvent(event(.leftMouseUp))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
