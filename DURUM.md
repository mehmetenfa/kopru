# Durum (güncelleme: 2026-11-01)

## Şu an
v0.2.1: dosya listesi AppKit NSTableView'e geçti (çoklu seçim, sürükle-bırak indirme/yükleme, toplu indirme, kayıt yeri seçici, bağlantıyı kes). Derleniyor, uygulama açılıyor, `disconnect` CLI'da gerçek PC ile doğrulandı. **Arayüz etkileşimleri (seçme, sürükleme, panel) henüz elle denenmedi.**

v0.2 aktarım motoru yazıldı ve gerçek PC'de (`misal_ilim_ve_kltr@misalpc1`, Tailscale SSH → WSL2) doğrulandı. Pencereli uygulama henüz kullanıcı tarafından elle denenmedi.

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
