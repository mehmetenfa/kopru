import SwiftUI
import KopruCore
import AppKit

@MainActor
final class Model: ObservableObject {
    @Published var hosts = SSHConfig.hostAliases()
    @Published var host: String = SSHConfig.hostAliases().first ?? ""
    @Published var cwd = ""
    @Published var items: [RemoteItem] = []
    @Published var status = "Hazır"
    @Published var busy = false

    private var cached: SSHSession?
    private var sess: SSHSession {
        if let c = cached, c.host == host { return c }
        let n = SSHSession(host: host); cached = n; return n
    }

    func open(_ path: String?) {
        run("Klasör açılıyor…") {
            let r = try await self.sess.list(path)
            self.cwd = r.cwd; self.items = r.items; self.status = "\(r.items.count) öğe"
        }
    }

    func up() {
        guard !cwd.isEmpty else { return }
        open((cwd as NSString).deletingLastPathComponent.replacingOccurrences(of: "/", with: "\\"))
    }

    func download(_ item: RemoteItem) {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        run("\(item.name) indiriliyor…") {
            let u = try await self.sess.download(remote: item.FullName, toDirectory: dir, isDirectory: item.isDirectory)
            self.status = "✓ \(u.lastPathComponent) indirildi, doğrulandı"
            NSWorkspace.shared.activateFileViewerSelecting([u])
        }
    }

    func upload(_ urls: [URL]) {
        guard !cwd.isEmpty else { return }
        run("Yükleniyor…") {
            for u in urls { try await self.sess.upload(local: u, toRemoteDirectory: self.cwd) }
            self.status = "✓ \(urls.count) öğe yüklendi, doğrulandı"
            self.open(self.cwd)
        }
    }

    func pullClipboard() {
        run("Windows panosu alınıyor…") {
            switch try await self.sess.pullClipboard() {
            case .text(let t):
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(t, forType: .string)
                self.status = "✓ Metin Mac panosunda (\(t.count) karakter)"
            case .image(let u):
                if let img = NSImage(contentsOf: u) { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([img]) }
                self.status = "✓ Görsel Mac panosunda (PNG, kayıpsız)"
            }
        }
    }

    func pushClipboard() {
        run("Mac panosu Windows'a gönderiliyor…") {
            try await self.sess.pushClipboardText(NSPasteboard.general.string(forType: .string) ?? "")
            self.status = "✓ Windows panosuna gönderildi"
        }
    }

    func setupClipboard() {
        run("Pano yardımcısı kuruluyor…") {
            try await self.sess.installClipboardAgent(); self.status = "✓ Pano yardımcısı kuruldu"
        }
    }

    private func run(_ message: String, _ work: @escaping () async throws -> Void) {
        busy = true; status = message
        Task {
            do { try await work() } catch { status = "❌ \(error.localizedDescription)" }
            busy = false
        }
    }
}
