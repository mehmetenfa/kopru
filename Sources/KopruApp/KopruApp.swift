import SwiftUI
import AppKit
import KopruCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Pencere kapansa da menü çubuğunda çalışmaya devam eder (Çık ile kapanır)
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}

@main
struct KopruApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = Model()

    var body: some Scene {
        Window("Köprü", id: "main") {
            ContentView().environmentObject(model).frame(minWidth: 720, minHeight: 480)
        }
        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            Image(nsImage: MenuIcon.make(connected: model.connected))
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var m: Model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(m.connected ? "● Bağlı: \(m.displayName(for: m.host))" : "○ Bağlı değil")
        Divider()
        Button("Yeni bilgisayar ekle…") {
            openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true); m.showGuide = true
        }
        Button("Köprü penceresini aç") {
            openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
        }
        if m.connected {
            Button("Bağlantıyı kes") { m.disconnect() }
        } else {
            Button("Bağlan") { m.connect() }
                .disabled(SSHSession.normalizeHost(m.host).isEmpty || m.busy)
        }
        if !m.connected && !m.devices.isEmpty {
            Divider()
            ForEach(m.devices.prefix(6)) { d in
                Button("Bağlan: \(d.name)") { m.connect(to: d) }.disabled(m.busy)
            }
        }
        Divider()
        Button("Windows panosunu al") { m.pullClipboard() }.disabled(!m.connected || m.busy)
        Button("Mac panosunu Windows'a gönder") { m.pushClipboard() }.disabled(!m.connected || m.busy)
        Divider()
        if m.busy {
            Text(m.progress?.summary ?? m.status)
            Button("Aktarımı iptal et") { m.cancel() }
        } else {
            Text(m.status)
        }
        Divider()
        Button("Köprü'den çık") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

/// Menü çubuğu simgesi: köprü kemeri (şablon görüntü, açık/koyu temaya uyar). Bağlıyken sağ üstte nokta.
enum MenuIcon {
    static func make(connected: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { _ in
            NSColor.black.setStroke(); NSColor.black.setFill()
            let arch = NSBezierPath()
            arch.move(to: NSPoint(x: 2.5, y: 5.5))
            arch.curve(to: NSPoint(x: 17.5, y: 5.5), controlPoint1: NSPoint(x: 5, y: 15), controlPoint2: NSPoint(x: 15, y: 15))
            arch.lineWidth = 1.7; arch.lineCapStyle = .round; arch.stroke()
            let deck = NSBezierPath()
            deck.move(to: NSPoint(x: 1, y: 5.5)); deck.line(to: NSPoint(x: 19, y: 5.5))
            deck.lineWidth = 2; deck.lineCapStyle = .round; deck.stroke()
            for x in [5.0, 15.0] {
                let leg = NSBezierPath(); leg.move(to: NSPoint(x: x, y: 5)); leg.line(to: NSPoint(x: x, y: 1.2))
                leg.lineWidth = 1.7; leg.lineCapStyle = .round; leg.stroke()
            }
            if connected { NSBezierPath(ovalIn: NSRect(x: 14.5, y: 10.5, width: 5, height: 5)).fill() }
            return true
        }
        img.isTemplate = true
        return img
    }
}
