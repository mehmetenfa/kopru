import SwiftUI
import AppKit
import KopruCore

/// "Yeni bilgisayar ekle" rehberi: yöntemi seç → Windows'ta çalıştırılacak komutlar → bilgileri gir → bağlantıyı dene → kaydet.
struct NewComputerGuide: View {
    @EnvironmentObject var m: Model
    @Environment(\.dismiss) private var dismiss

    enum Method: String, CaseIterable, Identifiable {
        case tailscale = "Tailscale ile (önerilen)"
        case lan = "Aynı ağdan (Tailscale'siz)"
        var id: String { rawValue }
    }

    @State private var method: Method = .tailscale
    @State private var user = ""
    @State private var address = ""
    @State private var name = ""
    @State private var report: ConnectionReport?
    @State private var testing = false

    private var hostString: String {
        let u = user.trimmingCharacters(in: .whitespaces), a = address.trimmingCharacters(in: .whitespaces)
        return u.isEmpty ? a : "\(u)@\(a)"
    }
    private var hasMacKey: Bool {
        ["id_ed25519.pub", "id_rsa.pub", "id_ecdsa.pub"].contains { FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.ssh/\($0)") }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Yeni bilgisayar ekle").font(.title2.bold())
                Spacer()
                Button("Kapat") { dismiss() }
            }.padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bağlanmak istediğin Windows bilgisayarda birkaç komut çalıştıracaksın. Komutları kopyalayıp **WSL terminaline** (Başlat menüsünde “Ubuntu” ya da “WSL”) yapıştır.")
                        .font(.callout).foregroundStyle(.secondary)

                    step(1, "Yöntemi seç") {
                        Picker("", selection: $method) { ForEach(Method.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).labelsHidden()
                        Text(method == .tailscale
                             ? "Farklı ağlardan bile çalışır ve anahtar kurmana gerek kalmaz. İki bilgisayarda da aynı Tailscale hesabı açık olmalı."
                             : "Yalnızca aynı ev/ofis ağındayken çalışır. Mac'ten bir anahtar eklemen gerekir.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    step(2, "Windows bilgisayarda, WSL terminalinde çalıştır") {
                        if method == .tailscale {
                            CommandBox("curl -fsSL https://tailscale.com/install.sh | sh")
                            CommandBox("sudo tailscale up --ssh")
                            Text("İkinci komut bir bağlantı yazdırır; onu tarayıcıda açıp kendi Tailscale hesabınla onayla.").font(.caption).foregroundStyle(.secondary)
                            Text("Sonra bu iki bilgiyi bul:").font(.callout)
                            CommandBox("whoami")
                            Text("↑ kullanıcı adı").font(.caption).foregroundStyle(.secondary)
                            CommandBox("tailscale status | head -n 1")
                            Text("↑ ikinci sütun cihaz adı (ör. “100.x.x.x  **misalpc1**  …”)").font(.caption).foregroundStyle(.secondary)
                            DisclosureGroup("Hata alırsan") {
                                Text("“systemd” hatası çıkarsa WSL'de `sudo nano /etc/wsl.conf` ile dosyaya şunları ekle:\n[boot]\nsystemd=true\nsonra Windows PowerShell'de `wsl --shutdown` yazıp WSL'i yeniden aç.")
                                    .font(.caption).textSelection(.enabled)
                            }.font(.caption)
                        } else {
                            CommandBox("sudo apt update && sudo apt install -y openssh-server rsync")
                            CommandBox("sudo systemctl enable --now ssh")
                            CommandBox("whoami")
                            Text("↑ kullanıcı adı").font(.caption).foregroundStyle(.secondary)
                            Text("WSL'in dışarıdan görünmesi için Windows'ta (WSL'de değil) `C:\\Users\\<ad>\\.wslconfig` dosyasına şunu ekle, sonra PowerShell'de `wsl --shutdown` yap:").font(.callout)
                            CommandBox("[wsl2]\nnetworkingMode=mirrored")
                            Text("Adres olarak Windows'un yerel IP'sini kullan: PowerShell'de `ipconfig` yaz, “IPv4 Address” satırına bak (ör. 192.168.1.20).").font(.caption).foregroundStyle(.secondary)
                            DisclosureGroup("Bağlanamazsan (güvenlik duvarı)") {
                                Text("Windows PowerShell'i yönetici olarak açıp çalıştır:").font(.caption)
                                CommandBox("Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-57B6CF9F5B52}' -DefaultInboundAction Allow")
                                Text("Windows 11 22H2 ve üstü içindir. Eski Windows'ta mirrored ağ modu yoktur.").font(.caption).foregroundStyle(.secondary)
                            }.font(.caption)
                        }
                    }

                    step(3, "Bilgileri gir") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Kullanıcı adı").font(.caption).foregroundStyle(.secondary)
                                TextField("whoami çıktısı", text: $user).textFieldStyle(.roundedBorder)
                            }
                            Text("@").padding(.top, 14)
                            VStack(alignment: .leading) {
                                Text(method == .tailscale ? "Cihaz adı (Tailscale)" : "IP adresi / bilgisayar adı").font(.caption).foregroundStyle(.secondary)
                                TextField(method == .tailscale ? "ör. misalpc1" : "ör. 192.168.1.20", text: $address).textFieldStyle(.roundedBorder)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Bu bilgisayara bir ad ver (isteğe bağlı)").font(.caption).foregroundStyle(.secondary)
                            TextField("ör. Ofis PC", text: $name).textFieldStyle(.roundedBorder)
                        }
                    }

                    if method == .lan {
                        step(4, "Mac'inin anahtarını o bilgisayara ekle") {
                            if !hasMacKey {
                                Text("Mac'inde henüz SSH anahtarı yok. Önce Terminal'de şunu çalıştır (sorulara Enter'a basman yeterli):").font(.callout)
                                CommandBox("ssh-keygen -t ed25519")
                            }
                            Text("Terminal'de çalıştır (bir kez Windows/WSL kullanıcı parolası sorar):").font(.callout)
                            CommandBox("ssh-copy-id \(hostString.isEmpty ? "kullanıcı@adres" : hostString)")
                        }
                    }

                    step(method == .lan ? 5 : 4, "Bağlantıyı dene") {
                        HStack {
                            Button { test() } label: {
                                if testing { ProgressView().controlSize(.small) } else { Label(report == nil ? "Bağlantıyı dene" : "Tekrar dene", systemImage: "checkmark.shield") }
                            }.disabled(testing || user.trimmingCharacters(in: .whitespaces).isEmpty || address.trimmingCharacters(in: .whitespaces).isEmpty)
                            if testing { Text("Deneniyor… (en fazla 25 sn)").font(.caption).foregroundStyle(.secondary) }
                        }
                        if let r = report { ReportView(report: r) }
                    }
                }.padding()
            }
            Divider()
            HStack {
                Spacer()
                Button {
                    m.addAndConnect(host: hostString, name: name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                } label: { Label("Kaydet ve bağlan", systemImage: "bolt.fill") }
                    .buttonStyle(.borderedProminent).disabled(report?.usable != true)
            }.padding()
        }
        .frame(width: 620, height: 700)
    }

    private func test() {
        testing = true; report = nil
        let h = hostString
        Task { let r = await ConnectionCheck.run(host: h); await MainActor.run { report = r; testing = false } }
    }

    private func step<Content: View>(_ n: Int, _ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(n)").font(.caption.bold()).foregroundStyle(.white).frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor))
                Text(title).font(.headline)
            }
            content()
        }
    }
}

struct CommandBox: View {
    let text: String
    @State private var copied = false
    init(_ t: String) { text = t }
    var body: some View {
        HStack(alignment: .top) {
            Text(text).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: { Label(copied ? "Kopyalandı" : "Kopyala", systemImage: copied ? "checkmark" : "doc.on.doc") }
                .buttonStyle(.borderless).font(.caption)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
    }
}

struct ReportView: View {
    let report: ConnectionReport
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(report.title, systemImage: report.usable ? "checkmark.circle.fill" : (report.connected ? "exclamationmark.triangle.fill" : "xmark.octagon.fill"))
                .font(.headline).foregroundStyle(report.usable ? Color.green : (report.connected ? Color.orange : Color.red))
            ForEach(Array(report.items.enumerated()), id: \.offset) { _, it in
                Text((it.ok ? "✓ " : "✗ ") + it.text).font(.callout).foregroundStyle(it.ok ? Color.primary : Color.red)
            }
            if !report.hint.isEmpty { Text(report.hint).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let url = report.link { Button("Onay bağlantısını aç") { NSWorkspace.shared.open(url) } }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}
