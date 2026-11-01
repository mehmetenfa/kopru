import SwiftUI
import KopruCore
import AppKit

@MainActor
final class Model: ObservableObject {
    @Published var hosts = SSHConfig.hostAliases()
    @Published var host: String = UserDefaults.standard.string(forKey: "lastHost") ?? SSHConfig.hostAliases().first ?? ""
    @Published var connected = false
    @Published var cwd = ""
    @Published var items: [RemoteItem] = []
    @Published var selection: [RemoteItem] = []
    @Published var status = "Hazır"
    @Published var busy = false
    @Published var progress: TransferProgress?
    @Published var batchInfo = ""
    @Published var verify = true
    @Published var askEachTime: Bool = UserDefaults.standard.object(forKey: "askEachTime") as? Bool ?? true {
        didSet { UserDefaults.standard.set(askEachTime, forKey: "askEachTime") }
    }
    @Published var destination: URL = {
        if let p = UserDefaults.standard.string(forKey: "destination"), FileManager.default.fileExists(atPath: p) { return URL(fileURLWithPath: p) }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }() {
        didSet { UserDefaults.standard.set(destination.path, forKey: "destination") }
    }

    private var cached: SSHSession?
    private var currentTask: Task<Void, Never>?
    private var activity: NSObjectProtocol?

    init() {
        // Uygulama kapanırken kalıcı ssh bağlantısı arkada kalmasın
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.cached?.disconnectBlocking() }
        }
    }

    private var sess: SSHSession {
        if let c = cached, c.host == SSHSession.normalizeHost(host) { return c }
        let n = SSHSession(host: host); cached = n; return n
    }

    private var report: ProgressHandler { { [weak self] p in Task { @MainActor in self?.progress = p } } }

    var desktop: URL { FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0] }
    var downloads: URL { FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0] }
    var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    // MARK: bağlantı

    func connect() { open(nil) }

    func disconnect() {
        let s = cached
        currentTask?.cancel()
        let t = currentTask
        Task {
            _ = await t?.value
            await s?.disconnect()
            connected = false; items = []; selection = []; cwd = ""
            status = "Bağlantı kesildi"
        }
    }

    func open(_ path: String?) {
        UserDefaults.standard.set(host, forKey: "lastHost")
        run("Bağlanılıyor…") {
            let r = try await self.sess.list(path)
            self.cwd = r.cwd; self.items = r.items; self.connected = true
            self.status = "\(r.items.count) öğe"
        }
    }

    func up() {
        guard !cwd.isEmpty else { return }
        open((cwd as NSString).deletingLastPathComponent)
    }

    // MARK: indirme

    func chooseDestination() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination
        panel.message = selection.count == 1 ? "“\(selection[0].name)” nereye indirilsin?" : "\(selection.count) öğe nereye indirilsin?"
        panel.prompt = "Buraya indir"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        destination = url
        return url
    }

    func downloadSelected(forceAsk: Bool = false, to fixed: URL? = nil) {
        let list = selection
        guard !list.isEmpty, !busy else { return }
        let dir: URL
        if let fixed { dir = fixed; destination = fixed }
        else if askEachTime || forceAsk { guard let d = chooseDestination() else { return }; dir = d }
        else { dir = destination }
        startBatch(list, to: dir)
    }

    private func startBatch(_ list: [RemoteItem], to dir: URL) {
        let verify = self.verify
        run("İndiriliyor…") {
            var done: [URL] = [], failed: [String] = []
            for (i, item) in list.enumerated() {
                self.batchInfo = list.count > 1 ? "(\(i + 1)/\(list.count)) \(item.name)" : item.name
                do {
                    let u = try await self.sess.download(remote: item.path, toDirectory: dir, isDirectory: item.isDirectory,
                                                         verify: verify, onProgress: self.report)
                    done.append(u)
                } catch is CancellationError { throw CancellationError() }
                catch { failed.append("\(item.name): \(error.localizedDescription)") }
            }
            self.batchInfo = ""
            let name = dir.lastPathComponent
            self.status = failed.isEmpty
                ? "✓ \(done.count) öğe “\(name)” klasörüne indirildi" + (verify ? ", doğrulandı" : "")
                : "⚠️ \(done.count) indi, \(failed.count) başarısız — " + failed.joined(separator: " | ")
            if !done.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(done) }
        }
    }

    /// Finder'a/masaüstüne sürüklenen öğe: bırakılınca çağrılır, dosya `dest` konumuna yazılır.
    func promiseDownload(_ item: RemoteItem, to dest: URL) async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("kopru-drag-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        status = "“\(item.name)” indiriliyor (sürükle-bırak)…"
        let got = try await sess.download(remote: item.path, toDirectory: tmp, isDirectory: item.isDirectory,
                                          verify: verify, onProgress: report)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: got, to: dest)
        status = "✓ “\(item.name)” bırakılan yere kaydedildi"
        progress = nil
    }

    // MARK: yükleme

    func upload(_ urls: [URL], into folder: RemoteItem? = nil) {
        guard connected, !busy else { return }
        let dir = folder?.path ?? cwd
        let verify = self.verify
        run("Yükleniyor…") {
            for (i, u) in urls.enumerated() {
                self.batchInfo = urls.count > 1 ? "(\(i + 1)/\(urls.count)) \(u.lastPathComponent)" : u.lastPathComponent
                try await self.sess.upload(local: u, toRemoteDirectory: dir, verify: verify, onProgress: self.report)
            }
            self.batchInfo = ""
            self.status = "✓ \(urls.count) öğe yüklendi" + (verify ? ", doğrulandı" : "")
            self.open(self.cwd)
        }
    }

    // MARK: pano

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
            if let png = pb.data(forType: .png) { try await self.sess.pushClipboardImage(png: png) }
            else { try await self.sess.pushClipboardText(pb.string(forType: .string) ?? "") }
            self.status = "✓ Windows panosuna gönderildi"
        }
    }

    // MARK: iptal / çalıştırma

    func cancel() { currentTask?.cancel() }

    private func run(_ message: String, _ work: @escaping () async throws -> Void) {
        busy = true; status = message; progress = nil
        // Uzun aktarımlarda Mac uykuya geçmesin
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], reason: "Köprü aktarımı")
        currentTask = Task {
            do { try await work() }
            catch is CancellationError {
                status = "İptal edildi. Yarım dosya korundu; aynı aktarımı yeniden başlatınca kaldığı yerden devam eder."
            } catch { status = "❌ \(error.localizedDescription)" }
            busy = false; progress = nil; batchInfo = ""
            if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        }
    }
}
