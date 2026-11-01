import Foundation

/// Daha önce bağlanılan (kaydedilmiş) cihaz.
public struct Device: Codable, Identifiable, Hashable {
    public var host: String          // "kullanıcı@sunucu" ya da ~/.ssh/config takma adı
    public var name: String          // görünen ad (değiştirilebilir)
    public var lastConnected: Date?
    public var id: String { host }

    public init(host: String, name: String? = nil, lastConnected: Date? = nil) {
        self.host = host
        self.name = name ?? Device.defaultName(for: host)
        self.lastConnected = lastConnected
    }

    /// "ad@misalpc1" → "misalpc1"
    public static func defaultName(for host: String) -> String {
        host.split(separator: "@").last.map(String.init) ?? host
    }

    /// Cihazı listenin başına alır (yoksa ekler), son bağlantı zamanını günceller; adı korunur.
    public static func remembering(_ rawHost: String, in list: [Device], now: Date = Date()) -> [Device] {
        let host = SSHSession.normalizeHost(rawHost)
        guard !host.isEmpty else { return list }
        var out = list
        if let i = out.firstIndex(where: { $0.host == host }) {
            out[i].lastConnected = now
        } else {
            out.append(Device(host: host, lastConnected: now))
        }
        return sorted(out)
    }

    /// En son bağlanılan üstte; hiç bağlanılmayanlar sonda (ada göre).
    public static func sorted(_ list: [Device]) -> [Device] {
        list.sorted {
            switch ($0.lastConnected, $1.lastConnected) {
            case let (a?, b?): return a > b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}
