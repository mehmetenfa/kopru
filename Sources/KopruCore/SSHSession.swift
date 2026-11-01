import Foundation

/// Sistemdeki OpenSSH'ı kullanır. ControlMaster ile tek bağlantı paylaşılır:
/// her komut/aktarım yeniden el sıkışma yapmaz, bu yüzden hızlıdır.
///
/// Hedef WSL2 (Linux) olan Windows PC'dir: Windows sürücüleri /mnt/c, /mnt/d altındadır
/// ve Windows özelliklerine powershell.exe (WSL interop) üzerinden erişilir.
public final class SSHSession {
    /// "kullanıcı@sunucu" ya da ~/.ssh/config takma adı
    public let host: String
    let controlPath: String
    static let powershellPath = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    /// "ssh kullanıcı@sunucu" gibi terminal komutu yapıştırılırsa baştaki "ssh " ve boşluklar atılır.
    public static func normalizeHost(_ raw: String) -> String {
        var parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.first == "ssh" { parts.removeFirst() }
        return parts.last ?? ""
    }

    public init(host: String) {
        let host = Self.normalizeHost(host)
        self.host = host
        let dir = "/tmp/kopru-ssh-\(getuid())"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        self.controlPath = dir + "/%C"
    }

    var sshOptions: [String] {
        ["-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)",
         "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15", "-o", "Compression=no"]
    }

    private actor Gate {
        var inflight: Task<Void, Error>?
        func run(_ work: @escaping @Sendable () async throws -> Void) async throws {
            if let t = inflight { return try await t.value }
            let t = Task { try await work() }
            inflight = t
            defer { inflight = nil }
            try await t.value
        }
    }
    private let gate = Gate()

    /// Kalıcı ana bağlantıyı (ControlMaster) güvence altına alır; koptuysa yeniden kurar.
    /// Ana süreç çıktısı boru yerine dosyaya gider: arka planda kalan ssh süreci boruyu açık tutup
    /// okumayı sonsuza dek bekletmesin diye.
    func ensureMaster() async throws {
        let host = self.host, cp = controlPath
        let check = try await runProcess("/usr/bin/ssh", ["-o", "ControlPath=\(cp)", "-O", "check", host])
        if check.status == 0 { return }
        try await gate.run {
            let again = try await runProcess("/usr/bin/ssh", ["-o", "ControlPath=\(cp)", "-O", "check", host])
            if again.status == 0 { return }
            let log = URL(fileURLWithPath: NSTemporaryDirectory() + "kopru-master-\(getpid()).log")
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let h = try FileHandle(forWritingTo: log)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            p.arguments = ["-MNf", "-o", "ControlPath=\(cp)", "-o", "ControlPersist=10m", "-o", "BatchMode=yes",
                           "-o", "ServerAliveInterval=15", host]
            p.standardOutput = h; p.standardError = h; p.standardInput = FileHandle.nullDevice
            try p.run(); p.waitUntilExit()
            try? h.close()
            if p.terminationStatus != 0 {
                let msg = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
                throw KopruError.failed(SSHSession.clean(msg).isEmpty ? "ssh bağlantısı kurulamadı" : SSHSession.clean(msg))
            }
        }
    }

    /// Uzakta bash betiği çalıştırır. Betik base64 ile komut satırından gider,
    /// böylece stdin veri aktarımı için serbest kalır (powershell.exe stdin'i tüketir).
    @discardableResult
    public func sh(_ script: String, stdin: Data? = nil) async throws -> CommandResult {
        try await ensureMaster()
        let b64 = Data(script.utf8).base64EncodedString()
        let r = try await runProcess("/usr/bin/ssh", sshOptions + [host, "eval \"$(printf %s \(b64) | base64 -d)\""], stdin: stdin)
        if r.status != 0 { throw KopruError.failed(Self.clean(r.stderr).isEmpty ? "ssh çıkış kodu \(r.status)" : Self.clean(r.stderr)) }
        return r
    }

    /// Windows PowerShell'i (interop ile) çalıştırır. -STA: pano için gerekli.
    @discardableResult
    public func powershell(_ script: String, stdin: Data? = nil) async throws -> CommandResult {
        let enc = script.data(using: .utf16LittleEndian)!.base64EncodedString()
        return try await sh("\(Self.powershellPath) -NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand \(enc) | tr -d '\\r'", stdin: stdin)
    }

    static func clean(_ stderr: String) -> String {
        stderr.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }.joined(separator: "\n")
    }

    /// Kabuk için tek tırnaklı kaçış
    public static func shq(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Yalnızca ASCII üretir: ASCII dışı baytlar $'\ooo' olarak kaçırılır. Foundation'ın Process argümanlarında
    /// macOS dosya sistemi gibi Unicode'u ayrıştırması (ö → o + ¨) uzak yolu bozmasın diye rsync'e böyle verilir.
    public static func shqASCII(_ s: String) -> String {
        var out = "", run = ""
        func flush() { if !run.isEmpty { out += "'" + run.replacingOccurrences(of: "'", with: "'\\''") + "'"; run = "" } }
        for b in s.utf8 {
            if b < 0x80 && b >= 0x20 { run.append(Character(UnicodeScalar(b))) }
            else { flush(); out += "$'\\" + String(format: "%03o", b) + "'" }
        }
        flush()
        return out.isEmpty ? "''" : out
    }

    public func scp(_ args: [String]) async throws {
        try await ensureMaster()
        let r = try await runProcess("/usr/bin/scp", sshOptions + ["-p", "-q"] + args)
        if r.status != 0 { throw KopruError.failed(Self.clean(r.stderr)) }
    }
}
