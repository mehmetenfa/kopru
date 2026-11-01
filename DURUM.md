# Durum (güncelleme: 2026-11-01)

## Yayın
- GitHub: https://github.com/mehmetenfa/kopru (herkese açık, hesap: mehmetenfa)
- Sürüm: v0.3.0 → https://github.com/mehmetenfa/kopru/releases/tag/v0.3.0 (DMG, ZIP, SHA256SUMS; evrensel arm64+x86_64, ad-hoc imzalı, notarize DEĞİL)
- Yeni sürüm çıkarma: VERSION dosyasını artır → `scripts/make-dmg.sh` → commit/push → `GH_TOKEN=$(gh auth token -u mehmetenfa) gh release create vX.Y.Z dist/* --repo mehmetenfa/kopru`
- Not: `gh` aktif hesabı misalilim; bu repo için GH_TOKEN ile mehmetenfa kullanılır (global hesap değiştirilmedi).
- v0.3.0: menü çubuğu simgesi (bağlıyken nokta), pencere kapansa da çalışır, CLI uygulamanın içinde (Contents/Resources/kopru).

## Şu an
v0.3.1 (yayınlanmadı): cihaz listesi (Device, UserDefaults "devices") + yeni bilgisayar rehberi (NewComputerGuide, ConnectionCheck). 16 birim testi geçiyor; tanılama gerçek PC'de ve hatalı girişlerle (yanlış kullanıcı, olmayan adres, ulaşılamayan IP) CLI ile denendi. Arayüz elle denenmedi. **Tailscale'i sıfırdan kurma ve Tailscale'siz (mirrored/LAN) yöntem hiç test edilmedi**, rehberdeki komutlar belgelere dayanıyor. Yayın için VERSION'ı 0.3.1 yap → make-dmg → release.

v0.2.1: dosya listesi AppKit NSTableView'e geçti (çoklu seçim, sürükle-bırak indirme/yükleme, toplu indirme, kayıt yeri seçici, bağlantıyı kes). Derleniyor, uygulama açılıyor, `disconnect` CLI'da gerçek PC ile doğrulandı. **Arayüz etkileşimleri (seçme, sürükleme, panel) henüz elle denenmedi.**

v0.2 aktarım motoru yazıldı ve gerçek PC'de (Tailscale SSH ile erişilen, WSL2 içine giren bir Windows PC) doğrulandı. Pencereli uygulama henüz kullanıcı tarafından elle denenmedi.

## Gerçek PC'de doğrulananlar (CLI ile)
- Listeleme, pano (metin Windows→Mac), `run`; Türkçe karakterler
- 2 GB indirme: 22. sn'de Ctrl-C ile iptal → 320 MB yarım dosya korundu → aynı komutla %15'ten devam → SHA-256 yerel=uzak
- 1 GB yükleme: iptal → devam (193 MB'tan) → SHA-256 eşleşti
- Hız ~14-15 MB/sn indirme, ~9-10 MB/sn yükleme (Tailscale yoluna bağlı); ilerleme/hız/kalan süre doğru
- Aynı adlı dosya: "not (2).txt", "not (3).txt"; klasör indirme (ö/ş/ü'lü adlar); Windows Documents (İ/ü'lü yol) yükle+indir bayt bayt aynı
- Test dosyaları temizlendi

## Test edilmedi
- SwiftUI arayüzü (ilerleme çubuğu, iptal düğmesi, doğrulama kutusu) elle denenmedi
- 10+ GB dosyalar; bağlantının gerçekten kopup otomatik yeniden denemesi (yalnız iptal/devam denendi)
- Pano: görsel çekme, Mac→Windows gönderme
- Klasörde hash doğrulaması yok

## Öğrenilenler (CLAUDE.md "Tuzaklar"da da var)
- Mac'te yalnızca ~29 GB boş yer vardı: 40-50 GB dosya indirilemez, uygulama bunu başta söyler.
- macOS büyük/küçük harf duyarsız: `Kopru` ve `kopru` ürünleri aynı dosyaya düşüyordu → uygulama hedefi `KopruApp`.
- openrsync SIGTERM'de yarım dosyayı siler → iptal SIGKILL; `--partial` devam etmez, `--append` eder.
- `URL.resourceValues` dosya boyutunu önbellekler → `attributesOfItem`.
- `Process` argümanlarında Unicode ayrışır (ö→o+¨): uzak yollar rsync'e ASCII ($'\ooo') olarak verilir (`shqASCII`).
- ssh ControlMaster süreci boruları açık tutar → master dosyaya yönlendirilerek ayrı başlatılır; powershell.exe stdin'i tüketir → betikler base64 argümanla.
- `pgrep -f` Türkçe harfli (Köprü.app) yolu eşleştiremez (NFD): `pgrep -f MacOS/Kopru` kullan.
- macOS'ta `timeout` yok; `perl -e 'alarm N; exec @ARGV' --` kullan.

## Sıradaki
1. Kullanıcı `build/Köprü.app`'i açıp denesin; sorunları düzelt.
2. Ad kesinleşince GitHub deposu (kullanıcı onayıyla).
3. Ekran görüntüsü getirme, menü çubuğu, kuyruk.
