import Foundation

public struct TransferProgress: Sendable {
    public enum Phase: Sendable { case preparing, transferring, verifying, finishing }
    public var phase: Phase
    public var bytesDone: Int64 = 0
    public var bytesTotal: Int64 = 0
    public var bytesPerSecond: Double = 0
    public var etaSeconds: Double?
    public var attempt: Int = 1

    public init(phase: Phase, bytesDone: Int64 = 0, bytesTotal: Int64 = 0, bytesPerSecond: Double = 0, etaSeconds: Double? = nil, attempt: Int = 1) {
        self.phase = phase; self.bytesDone = bytesDone; self.bytesTotal = bytesTotal
        self.bytesPerSecond = bytesPerSecond; self.etaSeconds = etaSeconds; self.attempt = attempt
    }

    /// 0...1; toplam bilinmiyorsa 0
    public var fraction: Double { bytesTotal > 0 ? min(1, Double(bytesDone) / Double(bytesTotal)) : 0 }

    public var summary: String {
        switch phase {
        case .preparing: return attempt > 1 ? "Bağlantı yeniden kuruluyor… (deneme \(attempt))" : "Hazırlanıyor…"
        case .verifying: return "SHA-256 ile doğrulanıyor…"
        case .finishing: return "Tamamlanıyor…"
        case .transferring:
            var s = "\(Self.bytes(bytesDone)) / \(Self.bytes(bytesTotal)) · \(Self.bytes(Int64(bytesPerSecond)))/sn"
            if let e = etaSeconds { s += " · kalan \(Self.duration(e))" }
            return s
        }
    }

    public static func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

    public static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s) sn" }
        if s < 3600 { return "\(s / 60) dk" }
        return "\(s / 3600) sa \((s % 3600) / 60) dk"
    }
}

/// Son birkaç saniyelik örnekten hız hesaplar (anlık dalgalanmayı yumuşatır).
struct SpeedMeter {
    private var samples: [(t: TimeInterval, b: Int64)] = []
    let window: TimeInterval
    init(window: TimeInterval = 6) { self.window = window }

    mutating func add(_ bytes: Int64, at t: TimeInterval) -> Double {
        samples.append((t, bytes))
        while samples.count > 2, t - samples[0].t > window { samples.removeFirst() }
        guard let f = samples.first, let l = samples.last, l.t > f.t else { return 0 }
        return max(0, Double(l.b - f.b) / (l.t - f.t))
    }
}

enum SpaceCheck {
    static let margin: Int64 = 512 * 1024 * 1024
    static func require(needed: Int64, free: Int64, where place: String) throws {
        if needed + margin > free { throw KopruError.notEnoughSpace(needed: needed, free: free, where: place) }
    }
}

/// "dosya.txt" mevcutsa "dosya (2).txt", "dosya (3).txt"… döndürür.
func uniqueName(_ name: String, exists: (String) -> Bool) -> String {
    if !exists(name) { return name }
    let ns = name as NSString
    let ext = ns.pathExtension, base = ns.deletingPathExtension
    var i = 2
    while true {
        let cand = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
        if !exists(cand) { return cand }
        i += 1
    }
}
