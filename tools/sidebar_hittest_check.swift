import AppKit
import SwiftUI

final class SidebarHitLog {
    var selected: [Int] = []
}

struct SidebarHitRow: View {
    let index: Int
    let log: SidebarHitLog

    var body: some View {
        Button(action: { log.selected.append(index) }) {
            Text("row-\(index)")
                .frame(maxWidth: .infinity, minHeight: 70, maxHeight: 70, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("打开原网页") {}
        }
    }
}

struct SidebarHitList: View {
    let log: SidebarHitLog

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: SidebarQueueLayout.rowSpacing) {
                ForEach(0..<9, id: \.self) { index in
                    SidebarHitRow(index: index, log: log)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SidebarQueueLayout.listHorizontalPadding)
            .padding(.top, SidebarQueueLayout.listTopPadding)
            .padding(.bottom, SidebarQueueLayout.listBottomPadding)
        }
        .scrollIndicators(.hidden)
        .clipped()
    }
}

@main
struct SidebarHitTestCheck {
    @MainActor
    static func main() {
        assertLayoutPolicy()
        assertHostedGeometryAndClicks()
        print("sidebar_hittest_check=passed")
    }

    private static func assertLayoutPolicy() {
        // 头部 46 + 分隔线 1 + 列表顶垫 8 = 55。首行高 70，行距 4。
        precondition(SidebarQueueLayout.addBarHeight == 46)
        precondition(SidebarQueueLayout.listTopPadding == 8)
        precondition(SidebarQueueLayout.rowSpacing == 4)
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 20, rowHeight: 70, rowCount: 9) == nil,
            "点在添加栏内不得选中队列行"
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 31, rowHeight: 70, rowCount: 9) == nil,
            "标题栏区域不得再充当第 1 行命中区"
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 50, rowHeight: 70, rowCount: 9) == nil,
            "添加栏下的 8 点顶垫不得映射到任何行"
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 90, rowHeight: 70, rowCount: 9) == 0,
            "视觉第 1 行中心必须落到第 1 行"
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 141, rowHeight: 70, rowCount: 9) == 1,
            "视觉第 2 行不得再被第 1 行的位移命中区吃掉"
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 240, rowHeight: 70, rowCount: 9) == 2
        )
        precondition(
            SidebarQueueLayout.rowIndex(atWindowY: 312, rowHeight: 70, rowCount: 9) == 3
        )
    }

    private static func assertHostedGeometryAndClicks() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)

        let log = SidebarHitLog()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1500, height: 980),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false

        let root = NavigationSplitView {
            SidebarQueueChrome {
                Color.blue
            } content: {
                SidebarHitList(log: log)
            }
            .navigationSplitViewColumnWidth(min: 272, ideal: 312, max: 360)
        } detail: {
            Color.gray
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 980, minHeight: 640)

        let host = NSHostingView(rootView: root)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<14 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            window.layoutIfNeeded()
            host.layoutSubtreeIfNeeded()
        }

        guard let scroll = sidebarScrollView(in: host) else {
            preconditionFailure("侧栏队列必须有 NSScrollView")
        }

        precondition(
            scroll.contentInsets.top == 0,
            "队列滚动不得再继承标题栏 contentInsets，当前 top=\(scroll.contentInsets.top)"
        )
        precondition(
            abs(scroll.contentView.bounds.origin.y) < 1,
            "clip 原点仍偏移 \(scroll.contentView.bounds.origin.y)，画面会和命中错位"
        )

        let scrollInHost = scroll.convert(scroll.bounds, to: host)
        precondition(
            scrollInHost.minY >= SidebarQueueLayout.addBarHeight - 2,
            "滚动视图必须从添加栏下方开始，不能铺满标题栏。实际 minY=\(scrollInHost.minY)"
        )

        click(window, topY: 20)
        precondition(log.selected.isEmpty, "点添加栏不得选中队列行，实际 \(log.selected)")

        log.selected.removeAll()
        click(window, topY: 50)
        precondition(log.selected.isEmpty, "点添加栏与首行之间的 8 点顶垫不得选中队列行，实际 \(log.selected)")

        click(window, topY: 90)
        precondition(log.selected == [0], "点视觉第 1 行应选中第 1 行，实际 \(log.selected)")

        log.selected.removeAll()
        click(window, topY: 141)
        precondition(log.selected == [1], "点视觉第 2 行应选中第 2 行，实际 \(log.selected)")

        log.selected.removeAll()
        click(window, topY: 240)
        precondition(log.selected == [2], "点视觉第 3 行应选中第 3 行，实际 \(log.selected)")

        log.selected.removeAll()
        click(window, topY: 312)
        precondition(log.selected == [3], "点视觉第 4 行应选中第 4 行，实际 \(log.selected)")

        window.close()
    }

    private static func sidebarScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.frame.width < 400 {
            return scroll
        }
        for child in view.subviews {
            if let found = sidebarScrollView(in: child) {
                return found
            }
        }
        return nil
    }

    private static func click(_ window: NSWindow, topY: CGFloat) {
        guard let content = window.contentView else { return }
        let location = NSPoint(x: 80, y: content.bounds.height - topY)
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
