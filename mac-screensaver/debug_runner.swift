import AppKit
import ScreenSaver

@main
class DebugAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var screensaverView: OverheadTrackerScreensaverView!

    static func main() {
        let app = NSApplication.shared
        let delegate = DebugAppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 1024, height: 768)
        
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Overhead Tracker Screensaver Debugger"
        window.center()
        
        screensaverView = OverheadTrackerScreensaverView(frame: window.contentView!.bounds, isPreview: false)
        screensaverView.autoresizingMask = [.width, .height]
        
        window.contentView?.addSubview(screensaverView)
        window.makeKeyAndOrderFront(nil)
        
        // Start the screensaver animation/loading loop
        screensaverView.startAnimation()
        
        // Ensure app activates and brings window to front
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        screensaverView?.stopAnimation()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
