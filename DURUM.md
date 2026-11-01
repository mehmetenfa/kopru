# Durum (güncelleme: 2026-11-01)

## Şu an
v0.1 çalışıyor. Hedef bilgisayar (`misal_ilim_ve_kltr@misalpc1`, Tailscale SSH) gerçekte **WSL2 (Linux)** içine giriyor; Windows sürücüleri /mnt/c, /mnt/d. Mimari buna göre yeniden yazıldı.

## Gerçek PC'de doğrulananlar (CLI ile)
- Klasör listeleme (Türkçe/boşluklu adlar dahil), Windows kullanıcı klasörünü bulma (powershell.exe + wslpath)
- Pano Windows → Mac (metin) çalıştı; powershell.exe interop sayesinde ek kurulum yok
- 100 MB dosya yükleme/indirme: bayt bayt aynı, SHA-256 doğrulaması geçti (~10-13 MB/sn, Tailscale yoluna bağlı)
- `run` komutu, Türkçe karakterler bozulmadan

## Test edilmedi
- SwiftUI arayüzü gerçek kullanımda (derleniyor ve .app üretiliyor ama elle tıklanıp denenmedi)
- Pano: görsel (PNG) çekme, Mac → Windows gönderme (metin/görsel)
- Klasör indirme/yükleme; klasörde hash doğrulaması yok

## Öğrenilenler
- ssh ControlMaster arka plan süreci stdout borusunu açık tutar → okuma sonsuza dek bekler; master dosyaya yönlendirilerek ayrı başlatılıyor.
- powershell.exe stdin'i tüketir → betikler base64 argümanla gidiyor.
- Tailscale SSH ilk bağlantıda tarayıcıda onay isteyebilir; bu oturumda onaylı.
- macOS'ta `timeout` yok; testlerde `perl -e 'alarm N; exec @ARGV' --` kullan.

## Sıradaki
1. Kullanıcı .app'i açıp arayüzü denesin; hataları düzelt.
2. İlerleme çubuğu, ekran görüntüsü getirme, menü çubuğu.
3. Ad kesinleşince GitHub deposu (kullanıcı onayıyla).
