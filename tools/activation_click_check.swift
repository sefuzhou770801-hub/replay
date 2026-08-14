import AppKit

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

        print("activation_click_check=passed")
    }
}
