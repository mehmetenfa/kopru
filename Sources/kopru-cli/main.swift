import Foundation
import AppKit
import KopruCore

func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }

let usage = """
kopru — Mac'ten SSH ile Windows'a kayıpsız erişim

  kopru hosts                          ~/.ssh/config içindeki sunucular
  kopru <host> ls [yol]                Windows klasörünü listele
  kopru <host> get <uzak-yol> [hedef]  İndir (devam eder, SHA-256 doğrulamalı, Ctrl-C iptal)
  kopru <host> put <yerel> <uzak-klasör>  Yükle (SHA-256 doğrulamalı)
  kopru <host> run "<bash>"            WSL'de komut çalıştır, çıktısı stdout'a (| pbcopy ile panoya)
  kopru <host> clip [pull|push]        Windows panosunu al / Mac panosunu gönder
"""

let a = Array(CommandLine.arguments.dropFirst())
guard let first = a.first else { print(usage); exit(0) }
if first == "hosts" { SSHConfig.hostAliases().forEach { print($0) }; exit(0) }
guard a.count >= 2 else { print(usage); exit(1) }

let s = SSHSession(host: first)
let cmd = a[1]
let rest = Array(a.dropFirst(2))

func printProgress(_ p: TransferProgress) {
    let pct = p.phase == .transferring ? String(format: "%3.0f%% ", p.fraction * 100) : ""
    FileHandle.standardError.write(Data(("\r\u{1B}[K" + pct + p.summary).utf8))
}

let mainTask = Task {
    do {
        switch cmd {
        case "ls":
            let (cwd, items) = try await s.list(rest.first)
            print(cwd)
            for i in items { print(i.isDirectory ? "d" : "-", String(format: "%12lld", i.size), i.name) }
        case "get":
            guard let r = rest.first else { fail(usage) }
            let dir = URL(fileURLWithPath: rest.count > 1 ? rest[1] : FileManager.default.currentDirectoryPath)
            let isDir = try await s.isRemoteDirectory(r)
            let u = try await s.download(remote: r, toDirectory: dir, isDirectory: isDir, onProgress: printProgress)
            FileHandle.standardError.write(Data("\r\u{1B}[K".utf8))
            print("✓ \(u.path)")
        case "put":
            guard rest.count >= 2 else { fail(usage) }
            try await s.upload(local: URL(fileURLWithPath: rest[0]), toRemoteDirectory: rest[1], onProgress: printProgress)
            FileHandle.standardError.write(Data("\r\u{1B}[K".utf8))
            print("✓ yüklendi")
        case "run":
            guard let script = rest.first else { fail(usage) }
            FileHandle.standardOutput.write(try await s.sh(script).stdout)
        case "clip":
            let pb = NSPasteboard.general
            if rest.first == "push" {
                if let png = pb.data(forType: .png) { try await s.pushClipboardImage(png: png) }
                else { try await s.pushClipboardText(pb.string(forType: .string) ?? "") }
                print("✓ Windows panosuna gönderildi")
            } else {
                switch try await s.pullClipboard() {
                case .text(let t): pb.clearContents(); pb.setString(t, forType: .string); print("✓ metin Mac panosunda (\(t.count) karakter)")
                case .image(let d): pb.clearContents(); pb.setData(d, forType: .png); print("✓ görsel Mac panosunda (PNG, kayıpsız)")
                case .empty: print("Windows panosu boş")
                }
            }
        default: print(usage)
        }
        exit(0)
    } catch is CancellationError {
        fail("\nİptal edildi. Yarım dosya korundu; aynı komutu tekrar çalıştırınca kaldığı yerden devam eder.")
    } catch { fail("\nHata: \(error.localizedDescription)") }
}
// Ctrl-C: aktarımı düzgünce iptal et (yarım dosya devam için saklanır)
signal(SIGINT, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSrc.setEventHandler { mainTask.cancel() }
sigSrc.resume()
RunLoop.main.run()
