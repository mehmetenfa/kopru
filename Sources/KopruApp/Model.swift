import SwiftUI
import KopruCore
import AppKit

@MainActor
final class Model: ObservableObject {
    @Published var hosts = SSHConfig.hostAliases()
    @Published var host: String = UserDefaults.standard.string(forKey: "lastHost") ?? SSHConfig.hostAliases().first ?? ""
    @Published var cwd = ""
    @Published var items: [RemoteItem] = []
    @Published var status = "Hazır"
    @Published var busy = false
    @Published var progress: TransferProgress?
    @Published var verify = true
    private var currentTask: Task<Void, Never>?
    private var activity: NSObjectProtocol?

    func cancel() { currentTask?.cancel() }
    private var report: ProgressHandler { { [weak self] p in Task { @MainActor in self?.progress = p } } }

    private var cached: SSHSession?
    private var sess: SSHSession {
        if let c = cached, c.host == SSHSession.normalizeHost(host) { return c }
        let n = SSHSession(host: host); cached = n; return n
    }

    func open(_ path: String?) {
        UserDefaults.standard.set(host, forKey: "lastHost")
        run("Klasör açılıyor…") {
            let r = try await self.sess.list(path)
            self.cwd = r.cwd; self.items = r.items; self.status = "\(r.items.count) öğe"
        }
    }

    func up() {
        guard !cwd.isEmpty else { return }
        open((cwd as NSString).deletingLastPathComponent)
    }

    func download(_ item: RemoteItem) {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        run("\(item.name) indiriliyor…") {
            let u = try await self.sess.download(remote: item.path, toDirectory: dir, isDirectory: item.isDirectory,
                                                 verify: self.verify, onProgress: self.report)
            self.status = "✓ \(u.lastPathComponent) indirildi" + (self.verify && !item.isDirectory ? ", doğrulandı" : "")
            NSWorkspace.shared.activateFileViewerSelecting([u])
        }
    }

    func upload(_ urls: [URL]) {
        guard !cwd.isEmpty else { return }
        run("Yükleniyor…") {
            for u in urls { try await self.sess.upload(local: u, toRemoteDirectory: self.cwd, verify: self.verify, onProgress: self.report) }
            self.status = "✓ \(urls.count) öğe yüklendi" + (self.verify ? ", doğrulandı" : "")
            self.open(self.cwd)
        }
    }

    func pullClipboard() {
        run("Windows panosu alınıyor…") {
            let pb = NSPasteboard.general
            switch try await self.sess.pullClipboard() {
            case .text(let t):
                pb.clearContents(); pb.setString(t, forType: .string)
                self.status = "✓ Metin Mac panosunda (\(t.count) karakter)"
            case .image(let png):
                pb.clearContents(); pb.setData(png, forType: .png)
                self.status = "✓ Görsel Mac panosunda (PNG, kayıpsız, \(ByteCountFormatter.string(fromByteCount: Int64(png.count), countStyle: .file)))"
            case .empty: self.status = "Windows panosu boş"
            }
        }
    }

    func pushClipboard() {
        run("Mac panosu Windows'a gönderiliyor…") {
            let pb = NSPasteboard.general
            if let png = pb.data(forType: .png) {
                try await self.sess.pushClipboardImage(png: png)
            } else {
                try await self.sess.pushClipboardText(pb.string(forType: .string) ?? "")
            }
            self.status = "✓ Windows panosuna gönderildi"
        }
    }

    private func run(_ message: String, _ work: @escaping () async throws -> Void) {
        busy = true; status = message; progress = nil
        // Uzun aktarımlarda Mac uykuya geçmesin
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], reason: "Köprü aktarımı")
        currentTask = Task {
            do { try await work() }
            catch is CancellationError {
                status = "İptal edildi. Yarım dosya korundu; aynı aktarımı yeniden başlatınca kaldığı yerden devam eder."
            } catch { status = "❌ \(error.localizedDescription)" }
            busy = false; progress = nil
            if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        }
    }
}
