# Köprü — proje talimatları

Mac'ten SSH ile Windows PC'ye kayıpsız dosya/pano/komut erişimi sağlayan açık kaynak SwiftUI uygulaması.

## Yapı
- `Sources/KopruCore` — iş mantığı (SSH oturumu, uzak dosya sistemi, pano, hash). UI'dan bağımsız, testlenebilir.
- `Sources/KopruApp` — SwiftUI Mac uygulaması.
- `Sources/kopru-cli` — `kopru` komut satırı aracı (aynı çekirdeği kullanır).
- `scripts/build-app.sh` — `build/Köprü.app` üretir. `scripts/make-icon.swift` — logo.

## Kurallar
- Swift 5 dil modu, macOS 13+. Harici bağımlılık ekleme (sistem `ssh`/`scp` kullanılır).
- Hedef: SSH ile WSL2'ye (Linux) bağlanılan Windows PC. Windows sürücüleri /mnt/c, /mnt/d; Windows özellikleri `powershell.exe` (WSL interop, tam yol) ile. Windows/WSL'e kalıcı kurulum yapma.
- Uzak betikler `SSHSession.sh` ile base64 olarak gider (stdin veri için serbest kalır; powershell.exe stdin'i tüketir).
- ssh ControlMaster süreci boruları açık tutar: master daima dosyaya yönlendirilerek ayrı başlatılır (`ensureMaster`), asla boru ile.
- Aktarım kayıpsız olmalı: dosyalar bayt bayt kopyalanır, SHA-256 ile doğrulanır. Görseller PNG (yeniden sıkıştırma yok).
- PowerShell betikleri `-EncodedCommand` (UTF-16 base64) ile gönderilir.
- Kullanıcıya dönük metinler Türkçe (ileride yerelleştirme: ROADMAP).
- Gizli bilgi (anahtar, parola, host IP) repoya girmez.

## Git
- Commit author yalnızca proje sahibi. Commit/PR mesajlarına Claude ya da başka bir yapay zekâ imzası/Co-Authored-By EKLEME.
- Küçük, açıklayıcı commit'ler; Türkçe veya İngilizce.

## Her oturumda
1. `DURUM.md` oku. 2. İş bitince `DURUM.md` ve gerekirse `ROADMAP.md` güncelle. 3. `swift build && swift test`.

## Tuzaklar
- macOS dosya sistemi büyük/küçük harfe duyarsız: ürün adları `Kopru` ve `kopru` aynı dosyaya düşer. Uygulama hedefi bu yüzden `KopruApp`, CLI `kopru`.
- `URL.resourceValues` dosya boyutunu önbelleğe alır; ilerleme için `FileManager.attributesOfItem` kullan.
- openrsync SIGTERM alınca yarım dosyayı siler; iptalde SIGKILL gönderilir (`cancelSignal`).
