import Foundation

public typealias ProgressHandler = @Sendable (TransferProgress) -> Void

/// Büyük dosyalar için aktarım: rsync --append ile kaldığı yerden devam, ara klasörde (.kopru-partial)
/// yarım dosya, ilerleme/hız/kalan süre, iptal (Task iptali), otomatik yeniden deneme, boş alan kontrolü,
/// SHA-256 doğrulama, tamamlanınca yerine taşıma (adı çakışırsa "ad (2)").
public extension SSHSession {
    private var rsyncShell: String {
        "/usr/bin/ssh -o ControlMaster=no -o ControlPath=\(controlPath) -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3"
    }

    func isRemoteDirectory(_ path: String) async throws -> Bool {
        try await sh("[ -d \(Self.shq(path)) ] && echo d || echo f").text.hasPrefix("d")
    }

    func remoteSize(_ path: String) async throws -> Int64 {
        let r = try await sh("du -sb -- \(Self.shq(path)) 2>/dev/null | cut -f1")
        return Int64(r.text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func remoteFreeBytes(_ dir: String) async throws -> Int64 {
        let r = try await sh("df -B1 --output=avail -- \(Self.shq(dir)) | tail -n1")
        return Int64(r.text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Int64.max
    }

    static func localSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        // URL.resourceValues boyutu önbelleğe alır (eski değer döner); doğrudan stat kullan
        func size(_ u: URL) -> Int64 {
            guard let a = try? fm.attributesOfItem(atPath: u.path), a[.type] as? FileAttributeType == .typeRegular else { return 0 }
            return (a[.size] as? NSNumber)?.int64Value ?? 0
        }
        if !isDir.boolValue { return size(url) }
        var total: Int64 = 0
        if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for case let u as URL in e { total += size(u) }
        }
        return total
    }

    // MARK: rsync + izleme + yeniden deneme

    private func runRsync(_ args: [String], total: Int64, probeEvery: UInt64 = 1,
                          probe: @escaping @Sendable () async -> Int64, onProgress: @escaping ProgressHandler) async throws {
        let maxAttempts = 6
        var attempt = 1
        while true {
            try Task.checkCancellation()
            do {
                onProgress(TransferProgress(phase: attempt > 1 ? .preparing : .transferring, bytesTotal: total, attempt: attempt))
                try await ensureMaster()
                let monitor = Task {
                    var meter = SpeedMeter()
                    while !Task.isCancelled {
                        let done = await probe()
                        let speed = meter.add(done, at: ProcessInfo.processInfo.systemUptime)
                        let eta: Double? = speed > 1 && total > done ? Double(total - done) / speed : nil
                        onProgress(TransferProgress(phase: .transferring, bytesDone: done, bytesTotal: total,
                                                    bytesPerSecond: speed, etaSeconds: eta, attempt: attempt))
                        try? await Task.sleep(nanoseconds: probeEvery * 1_000_000_000)
                    }
                }
                defer { monitor.cancel() }
                let r = try await runProcess("/usr/bin/rsync", args, cancelSignal: SIGKILL)
                try Task.checkCancellation()
                if r.status != 0 { throw KopruError.failed(Self.clean(r.stderr).isEmpty ? "rsync çıkış kodu \(r.status)" : Self.clean(r.stderr)) }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Task.isCancelled { throw CancellationError() }
                if case KopruError.notEnoughSpace = error { throw error }
                if attempt >= maxAttempts { throw error }
                attempt += 1
                onProgress(TransferProgress(phase: .preparing, bytesTotal: total, attempt: attempt))
                try await Task.sleep(nanoseconds: UInt64(min(20, 1 << attempt)) * 1_000_000_000)
            }
        }
    }

    // MARK: indirme

    func download(remote: String, toDirectory dir: URL, isDirectory: Bool = false, verify: Bool = true,
                  onProgress: @escaping ProgressHandler = { _ in }) async throws -> URL {
        try await downloadImpl(remote: remote, dir: dir, isDirectory: isDirectory, verify: verify, onProgress: onProgress, cleanRestart: false)
    }

    private func downloadImpl(remote: String, dir: URL, isDirectory: Bool, verify: Bool,
                              onProgress: @escaping ProgressHandler, cleanRestart: Bool) async throws -> URL {
        onProgress(TransferProgress(phase: .preparing))
        try await ensureMaster()
        let fm = FileManager.default
        let total = try await remoteSize(remote)
        let stage = dir.appendingPathComponent(".kopru-partial")
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        let name = (remote as NSString).lastPathComponent
        let staged = stage.appendingPathComponent(name)
        let have = Self.localSize(staged)

        let free = (try? dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
        try SpaceCheck.require(needed: max(0, total - have), free: free, where: "Mac")

        try await runRsync(["-rlt", "--append", "-e", rsyncShell, "\(host):\(Self.shqASCII(remote))", stage.path + "/"],
                           total: total, probe: { Self.localSize(staged) }, onProgress: onProgress)

        if verify && !isDirectory {
            onProgress(TransferProgress(phase: .verifying, bytesDone: total, bytesTotal: total))
            async let l = Hashing.sha256(of: staged)
            async let r = remoteSHA256(remote)
            let (lh, rh) = try await (l, r)
            if lh != rh {
                try? fm.removeItem(at: staged)
                // Devam edilen dosyanın başı eski/farklı olabilir: bir kez sıfırdan dene
                if have > 0 && !cleanRestart {
                    return try await downloadImpl(remote: remote, dir: dir, isDirectory: isDirectory, verify: verify, onProgress: onProgress, cleanRestart: true)
                }
                throw KopruError.hashMismatch(local: lh, remote: rh)
            }
        }
        onProgress(TransferProgress(phase: .finishing, bytesDone: total, bytesTotal: total))
        let finalName = uniqueName(name) { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }
        let final = dir.appendingPathComponent(finalName)
        try fm.moveItem(at: staged, to: final)
        if (try? fm.contentsOfDirectory(atPath: stage.path))?.isEmpty == true { try? fm.removeItem(at: stage) }
        return final
    }

    // MARK: yükleme

    func upload(local: URL, toRemoteDirectory dir: String, verify: Bool = true,
                onProgress: @escaping ProgressHandler = { _ in }) async throws {
        onProgress(TransferProgress(phase: .preparing))
        try await ensureMaster()
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: local.path, isDirectory: &isDir)
        let total = Self.localSize(local)
        let stage = dir + "/.kopru-partial"
        let name = local.lastPathComponent
        let stagedRemote = stage + "/" + name
        try await sh("mkdir -p \(Self.shq(stage))")
        let have = try await remoteSize(stagedRemote)
        let free = try await remoteFreeBytes(dir)
        try SpaceCheck.require(needed: max(0, total - have), free: free, where: "Windows")

        try await runRsync(["-rlt", "--append", "-e", rsyncShell, local.path, "\(host):\(Self.shqASCII(stage))/"],
                           total: total, probeEvery: 2,
                           probe: { [self] in (try? await remoteSize(stagedRemote)) ?? 0 }, onProgress: onProgress)

        if verify && !isDir.boolValue {
            onProgress(TransferProgress(phase: .verifying, bytesDone: total, bytesTotal: total))
            async let l = Hashing.sha256(of: local)
            async let r = remoteSHA256(stagedRemote)
            let (lh, rh) = try await (l, r)
            if lh != rh {
                try? await sh("rm -rf -- \(Self.shq(stagedRemote))")
                throw KopruError.hashMismatch(local: lh, remote: rh)
            }
        }
        onProgress(TransferProgress(phase: .finishing, bytesDone: total, bytesTotal: total))
        try await sh("""
        S=\(Self.shq(stage)); D=\(Self.shq(dir)); N=\(Self.shq(name)); T="$D/$N"; i=2
        base="${N%.*}"; ext=""; if [[ "$N" == *.* && "${N#.}" == *.* ]]; then ext=".${N##*.}"; else base="$N"; fi
        while [ -e "$T" ]; do T="$D/$base ($i)$ext"; i=$((i+1)); done
        mv -- "$S/$N" "$T" && rmdir "$S" 2>/dev/null; true
        """)
    }
}
