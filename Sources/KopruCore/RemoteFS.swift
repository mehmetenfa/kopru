import Foundation
import CryptoKit

public struct RemoteItem: Identifiable, Hashable, Decodable {
    public let Name: String
    public let FullName: String
    public let IsDir: Bool
    public let Length: Int64
    public var id: String { FullName }
    public var name: String { Name }
    public var isDirectory: Bool { IsDir }
    public var size: Int64 { Length }
}

public extension SSHSession {
    /// Windows'ta bir klasörü listeler. path boşsa kullanıcı klasörü.
    func list(_ path: String?) async throws -> (cwd: String, items: [RemoteItem]) {
        let p = (path ?? "").replacingOccurrences(of: "'", with: "''")
        let script = """
        $ErrorActionPreference='Stop'
        $p = '\(p)'; if ($p -eq '') { $p = $env:USERPROFILE }
        $p = (Resolve-Path -LiteralPath $p).ProviderPath
        $items = @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
          [pscustomobject]@{ Name=$_.Name; FullName=$_.FullName; IsDir=[bool]$_.PSIsContainer; Length=[int64]$(if($_.PSIsContainer){0}else{$_.Length}) } })
        [pscustomobject]@{ cwd=$p; items=$items } | ConvertTo-Json -Depth 4 -Compress
        """
        let r = try await powershell(script)
        struct Payload: Decodable { let cwd: String; let items: [RemoteItem] }
        do {
            let d = try JSONDecoder().decode(Payload.self, from: r.stdout)
            return (d.cwd, d.items.sorted { ($0.isDirectory ? 0 : 1, $0.name.lowercased()) < ($1.isDirectory ? 0 : 1, $1.name.lowercased()) })
        } catch { throw KopruError.badRemoteOutput(String(r.text.prefix(200))) }
    }

    func remoteSHA256(_ path: String) async throws -> String {
        let p = path.replacingOccurrences(of: "'", with: "''")
        let r = try await powershell("(Get-FileHash -LiteralPath '\(p)' -Algorithm SHA256).Hash")
        return r.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Dosyayı olduğu gibi (bayt bayt) indirir; SHA-256 ile doğrular. Klasörler özyinelemeli iner (doğrulama yalnızca tek dosyada).
    func download(remote: String, toDirectory dir: URL, isDirectory: Bool = false, verify: Bool = true) async throws -> URL {
        try await scp((isDirectory ? ["-r"] : []) + [scpRemote(remote), dir.path])
        let name = remote.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? "dosya"
        let local = dir.appendingPathComponent(name)
        if verify && !isDirectory {
            let (l, r) = try await (Hashing.sha256(of: local), remoteSHA256(remote))
            if l != r { throw KopruError.hashMismatch(local: l, remote: r) }
        }
        return local
    }

    func upload(local: URL, toRemoteDirectory dir: String, verify: Bool = true) async throws {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: local.path, isDirectory: &isDir)
        let target = dir.replacingOccurrences(of: "\\", with: "/")
        try await scp((isDir.boolValue ? ["-r"] : []) + [local.path, "\(host):\(target)/"])
        if verify && !isDir.boolValue {
            let remote = target + "/" + local.lastPathComponent
            let (l, r) = try await (Hashing.sha256(of: local), remoteSHA256(remote))
            if l != r { throw KopruError.hashMismatch(local: l, remote: r) }
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
