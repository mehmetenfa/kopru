import Foundation

/// Sistemdeki OpenSSH'ı kullanır. ControlMaster ile tek bağlantı paylaşılır:
/// her komut/aktarım yeniden el sıkışma yapmaz, bu yüzden hızlıdır.
public final class SSHSession {
    public let host: String
    let controlPath: String

    public init(host: String) {
        self.host = host
        let dir = NSTemporaryDirectory() + "kopru-ssh"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        self.controlPath = dir + "/%C"
    }

    var sshOptions: [String] {
        ["-o", "ControlMaster=auto", "-o", "ControlPath=\(controlPath)", "-o", "ControlPersist=10m",
         "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15", "-o", "Compression=no"]
    }

    /// Windows'ta PowerShell betiği çalıştırır (-EncodedCommand: tırnak/kaçış sorunu yok).
    @discardableResult
    public func powershell(_ script: String) async throws -> CommandResult {
        let b64 = script.data(using: .utf16LittleEndian)!.base64EncodedString()
        let r = try await runProcess("/usr/bin/ssh", sshOptions + [host,
            "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand \(b64)"])
        if r.status != 0 { throw KopruError.failed(r.stderr.isEmpty ? "ssh çıkış kodu \(r.status)" : r.stderr) }
        return r
    }

    /// scp için uzak yol: "host:C:/Users/x/dosya"
    func scpRemote(_ path: String) -> String { "\(host):\(path.replacingOccurrences(of: "\\", with: "/"))" }

    public func scp(_ args: [String]) async throws {
        let r = try await runProcess("/usr/bin/scp", sshOptions + ["-p", "-q"] + args)
        if r.status != 0 { throw KopruError.failed(r.stderr) }
    }
}
