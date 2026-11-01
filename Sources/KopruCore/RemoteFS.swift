import Foundation
import CryptoKit

public struct RemoteItem: Identifiable, Hashable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public var id: String { path }
}

public extension SSHSession {
    /// Windows kullanıcı klasörünün WSL yolu (örn. /mnt/c/Users/Ad)
    func windowsHome() async throws -> String {
        let r = try await sh("""
        P=\(Self.powershellPath)
        UP=$($P -NoProfile -Command '[Console]::OutputEncoding=[Text.Encoding]::UTF8; $env:USERPROFILE' </dev/null | tr -d '\\r')
        wslpath -u "$UP"
        """)
        let p = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "/mnt/c" : p
    }

    /// Klasörü listeler (NUL ayraçlı: boşluklu/Türkçe/yeni satırlı adlar güvenli). path nil ise Windows kullanıcı klasörü.
    func list(_ path: String?) async throws -> (cwd: String, items: [RemoteItem]) {
        let dir: String
        if let path { dir = path } else { dir = try await windowsHome() }
        let r = try await sh("cd \(Self.shq(dir)) && pwd && find . -mindepth 1 -maxdepth 1 -printf '%y\\t%s\\t%f\\0'", stdin: nil)
        guard let nl = r.stdout.firstIndex(of: 0x0A) else { throw KopruError.badRemoteOutput(String(r.text.prefix(200))) }
        let cwd = String(decoding: r.stdout[..<nl], as: UTF8.self)
        var items: [RemoteItem] = []
        for rec in r.stdout[(nl + 1)...].split(separator: 0) {
            let parts = String(decoding: rec, as: UTF8.self).split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            let name = String(parts[2])
            items.append(RemoteItem(name: name, path: (cwd == "/" ? "" : cwd) + "/" + name,
                                    isDirectory: parts[0] == "d", size: Int64(parts[1]) ?? 0))
        }
        items.sort { ($0.isDirectory ? 0 : 1, $0.name.lowercased()) < ($1.isDirectory ? 0 : 1, $1.name.lowercased()) }
        return (cwd, items)
    }

    func remoteSHA256(_ path: String) async throws -> String {
        let r = try await sh("sha256sum -- \(Self.shq(path))")
        return String(r.text.split(separator: " ").first ?? "").lowercased()
    }

    /// Dosyayı bayt bayt indirir; tek dosyada SHA-256 ile doğrular. Klasörler özyinelemeli iner.
    func download(remote: String, toDirectory dir: URL, isDirectory: Bool = false, verify: Bool = true) async throws -> URL {
        try await scp((isDirectory ? ["-r"] : []) + ["\(host):\(remote)", dir.path])
        let local = dir.appendingPathComponent((remote as NSString).lastPathComponent)
        if verify && !isDirectory {
            async let l = Hashing.sha256(of: local)
            async let r = remoteSHA256(remote)
            let (lh, rh) = try await (l, r)
            if lh != rh { throw KopruError.hashMismatch(local: lh, remote: rh) }
        }
        return local
    }

    func upload(local: URL, toRemoteDirectory dir: String, verify: Bool = true) async throws {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: local.path, isDirectory: &isDir)
        try await scp((isDir.boolValue ? ["-r"] : []) + [local.path, "\(host):\(dir)/"])
        if verify && !isDir.boolValue {
            async let l = Hashing.sha256(of: local)
            async let r = remoteSHA256(dir + "/" + local.lastPathComponent)
            let (lh, rh) = try await (l, r)
            if lh != rh { throw KopruError.hashMismatch(local: lh, remote: rh) }
        }
    }
}

public enum Hashing {
    public static func sha256(of url: URL) async throws -> String {
        try await Task.detached {
            let h = try FileHandle(forReadingFrom: url)
            defer { try? h.close() }
            var hasher = SHA256()
            while let chunk = try h.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty { hasher.update(data: chunk) }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
