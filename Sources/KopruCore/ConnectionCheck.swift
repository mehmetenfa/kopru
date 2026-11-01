import Foundation

public struct ConnectionReport {
    public struct Item { public var ok: Bool; public var text: String }
    public var connected = false      // ssh bağlantısı kuruldu
    public var usable = false         // Köprü bu bilgisayarla çalışabilir (WSL + rsync + sha256sum)
    public var title = ""
    public var hint = ""
    public var link: URL?
    public var items: [Item] = []
}

/// Yeni bilgisayar rehberi için bağlantı tanılaması: ssh'ı dener, sonucu Türkçe ve çözümüyle açıklar.
public enum ConnectionCheck {
    static func firstTailscaleURL(in s: String) -> URL? {
        guard let r = s.range(of: #"https://[^\s]*tailscale\.com[^\s]*"#, options: .regularExpression) else { return nil }
        return URL(string: String(s[r]))
    }

    public static func explain(stderr raw: String, timedOut: Bool = false) -> (title: String, hint: String, link: URL?) {
        let s = SSHSession.clean(raw).isEmpty ? raw : raw   // '#' satırları (Tailscale mesajı) dahil tamamına bak
        let low = s.lowercased()
        if let url = firstTailscaleURL(in: s), low.contains("additional check") || timedOut {
            return ("Tailscale onayı bekleniyor",
                    "Bu bağlantıyı tarayıcıda açıp onayla, sonra “Tekrar dene”ye bas.", url)
        }
        if low.contains("tailnet policy does not permit") {
            return ("Tailscale bu bağlantıya izin vermiyor",
                    "tailscale.com yönetim sayfasında Access controls → SSH kuralı bu kullanıcı ve cihaz için izin vermeli. Kullanıcı adının doğru yazıldığını da kontrol et (başında “ssh” olmamalı).", nil)
        }
        if low.contains("permission denied") {
            return ("Giriş reddedildi (anahtar kabul edilmedi)",
                    "Mac'inin anahtarı o bilgisayara eklenmemiş. Rehberdeki “anahtarı ekle” adımındaki komutu Terminal'de çalıştır. Tailscale kullanıyorsan WSL'de `sudo tailscale up --ssh` çalıştırdığından emin ol.", nil)
        }
        if low.contains("could not resolve hostname") || low.contains("nodename nor servname") {
            return ("Adres bulunamadı", "Adres yanlış yazılmış olabilir. Tailscale'de cihaz adını, aynı ağda IP adresini kontrol et. Tailscale kullanıyorsan Mac'te de açık olmalı.", nil)
        }
        if low.contains("connection refused") {
            return ("Bilgisayar bulundu ama SSH sunucusu yanıt vermiyor",
                    "WSL'de `sudo systemctl enable --now ssh` çalıştırdığından ve Windows güvenlik duvarının 22 numaralı porta izin verdiğinden emin ol.", nil)
        }
        if low.contains("timed out") || low.contains("no route to host") || low.contains("network is unreachable") || timedOut {
            return ("Bilgisayara ulaşılamıyor",
                    "Bilgisayar kapalı, uykuda ya da farklı bir ağda olabilir. Aynı ağda değilseniz Tailscale kullanın. Güvenlik duvarı da engelliyor olabilir.", nil)
        }
        if low.contains("host key verification failed") || low.contains("remote host identification has changed") {
            return ("Sunucunun kimliği değişmiş",
                    "Bu adres daha önce başka bir bilgisayara aitti. Doğru bilgisayar olduğundan eminsen Terminal'de `ssh-keygen -R adres` çalıştırıp tekrar dene.", nil)
        }
        if low.contains("not recognized") || low.contains("command not found") || low.contains("eval") {
            return ("Bağlandı ama bu bilgisayar WSL (Linux) kabuğu açmıyor",
                    "Köprü şimdilik yalnızca SSH'ın WSL içine girdiği bilgisayarlarla çalışıyor. Sade Windows OpenSSH desteği yol haritasında.", nil)
        }
        let first = s.split(whereSeparator: \.isNewline).last.map(String.init) ?? "Bilinmeyen hata"
        return ("Bağlanılamadı", first, nil)
    }

    public static func run(host rawHost: String, timeout: TimeInterval = 25) async -> ConnectionReport {
        let host = SSHSession.normalizeHost(rawHost)
        var r = ConnectionReport()
        guard !host.isEmpty else { r.title = "Adres boş"; r.hint = "Kullanıcı adı ve adresi gir."; return r }

        let script = """
        echo KOPRU_OK
        if grep -qi microsoft /proc/version 2>/dev/null; then echo WSL=1; else echo WSL=0; fi
        if [ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]; then echo PS=1; else echo PS=0; fi
        if command -v rsync >/dev/null 2>&1; then echo RSYNC=1; else echo RSYNC=0; fi
        if command -v sha256sum >/dev/null 2>&1; then echo SHA=1; else echo SHA=0; fi
        """
        let b64 = Data(script.utf8).base64EncodedString()
        let args = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ControlMaster=no", "-o", "ControlPath=none", host, "eval \"$(printf %s \(b64) | base64 -d)\""]

        let work = Task { try await runProcess("/usr/bin/ssh", args) }
        let flag = TimeoutFlag()
        let timer = Task { try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)); if !Task.isCancelled { flag.set(); work.cancel() } }
        let res = try? await work.value
        timer.cancel()
        guard let res else { r.title = "Bağlanılamadı"; r.hint = "ssh başlatılamadı."; return r }

        guard res.status == 0, res.text.contains("KOPRU_OK") else {
            let e = explain(stderr: res.stderr, timedOut: flag.isSet)
            r.title = e.title; r.hint = e.hint; r.link = e.link
            return r
        }
        r.connected = true
        var flags: [String: Bool] = [:]
        for line in res.text.split(whereSeparator: \.isNewline) {
            let p = line.split(separator: "=")
            if p.count == 2 { flags[String(p[0])] = (p[1] == "1") }
        }
        let wsl = flags["WSL"] ?? false, ps = flags["PS"] ?? false, rs = flags["RSYNC"] ?? false, sha = flags["SHA"] ?? false
        r.items = [
            .init(ok: true, text: "SSH bağlantısı kuruldu"),
            .init(ok: wsl, text: wsl ? "WSL2 (Windows içindeki Linux) algılandı" : "Bu bir WSL değil (Köprü şimdilik WSL gerektiriyor)"),
            .init(ok: ps, text: ps ? "Windows özelliklerine erişim var (pano, kullanıcı klasörü)" : "Windows'a erişim yok (pano çalışmaz; WSL interop kapalı olabilir)"),
            .init(ok: rs, text: rs ? "rsync hazır (büyük dosyalar, devam etme)" : "rsync yok — WSL'de `sudo apt install rsync`"),
            .init(ok: sha, text: sha ? "sha256sum hazır (doğrulama)" : "sha256sum yok — WSL'de `sudo apt install coreutils`"),
        ]
        r.usable = wsl && rs && sha
        if r.usable { r.title = "Bağlantı başarılı"; r.hint = "Köprü bu bilgisayarla çalışmaya hazır." }
        else { r.title = "Bağlandı ama eksikler var"; r.hint = "Yukarıdaki ✗ satırlarını düzeltip tekrar dene." }
        return r
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock(); private var v = false
    func set() { lock.lock(); v = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return v }
}
