# Durum (güncelleme: 2026-11-01)

## Şu an
v0.1 iskeleti yazıldı; derleniyor, birim testi geçiyor, `build/Köprü.app` üretiliyor.

## Yapıldı
- SwiftPM projesi: KopruCore + Kopru (uygulama) + kopru-cli
- SSH ControlMaster ile hızlı oturum, PowerShell EncodedCommand
- Dosya listeleme / indirme / yükleme + SHA-256 doğrulama
- Pano yardımcısı (zamanlanmış görev /IT ile kullanıcı oturumunda çalışır)
- Logo ve .app paketleme betiği
- CLAUDE.md, ROADMAP.md, DURUM.md, README.md, MIT lisans

## Bilinen riskler / test edilmedi
- Hiçbir şey gerçek Windows makinede test edilmedi.
- Pano: sshd servis olarak çalıştığı için görev yaklaşımı varsayıma dayanıyor; kullanıcı oturumu açık olmalı.
- Mac→Windows pano gönderimi komut satırı sınırı nedeniyle uzun metinde (~20 KB+) başarısız olabilir.
- Klasör indirmede hash doğrulaması yok (yalnızca tek dosya).
- Proje adı geçici ("Köprü"); GitHub depo adı ve yayın henüz yok.

## Sıradaki
1. Kullanıcının Windows PC'siyle gerçek test (ls, get, put, clip).
2. İlerleme göstergesi, hata mesajlarını iyileştirme.
3. Ad kesinleşince GitHub deposu açıp yayınlama (kullanıcı onayıyla).
