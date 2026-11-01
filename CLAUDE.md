# Köprü — proje talimatları

Mac'ten SSH ile Windows PC'ye kayıpsız dosya/pano/komut erişimi sağlayan açık kaynak SwiftUI uygulaması.

## Yapı
- `Sources/KopruCore` — iş mantığı (SSH oturumu, uzak dosya sistemi, pano, hash). UI'dan bağımsız, testlenebilir.
- `Sources/Kopru` — SwiftUI Mac uygulaması.
- `Sources/kopru-cli` — `kopru` komut satırı aracı (aynı çekirdeği kullanır).
- `scripts/build-app.sh` — `build/Köprü.app` üretir. `scripts/make-icon.swift` — logo.

## Kurallar
- Swift 5 dil modu, macOS 13+. Harici bağımlılık ekleme (sistem `ssh`/`scp` kullanılır).
- Windows'a kalıcı kurulum yapma; yalnızca %LOCALAPPDATA%\Kopru altında yardımcı dosya.
- Aktarım kayıpsız olmalı: dosyalar bayt bayt kopyalanır, SHA-256 ile doğrulanır. Görseller PNG (yeniden sıkıştırma yok).
- Windows komutları `powershell -EncodedCommand` ile gönderilir (kaçış sorunlarını önler).
- Kullanıcıya dönük metinler Türkçe (ileride yerelleştirme: ROADMAP).
- Gizli bilgi (anahtar, parola, host IP) repoya girmez.

## Git
- Commit author yalnızca proje sahibi. Commit/PR mesajlarına Claude ya da başka bir yapay zekâ imzası/Co-Authored-By EKLEME.
- Küçük, açıklayıcı commit'ler; Türkçe veya İngilizce.

## Her oturumda
1. `DURUM.md` oku. 2. İş bitince `DURUM.md` ve gerekirse `ROADMAP.md` güncelle. 3. `swift build && swift test`.
