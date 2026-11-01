# Yol haritası

## v0.1 — Temel (kodlandı, Windows'ta test bekliyor)
- [x] ~/.ssh/config'ten sunucu seçimi
- [x] Uzak klasör gezme, indirme/yükleme (sürükle-bırak), SHA-256 doğrulama
- [x] Pano: Windows → Mac (metin, görsel PNG), Mac → Windows (metin)
- [x] `kopru` CLI (ls/get/put/run/clip)

## v0.2 — Hız ve güven
- [ ] İlerleme çubuğu + hız göstergesi, iptal, kuyruk
- [ ] Büyük klasörlerde tek tar akışı (çok sayıda küçük dosya için hızlı)
- [ ] Kesilen aktarımı sürdürme
- [ ] Gerçek Windows testleri (10/11, OpenSSH, varsayılan kabuk cmd ve PowerShell)

## v0.3 — Windows'a özel özellikler
- [ ] Windows ekran görüntüsü alıp Mac'e getir
- [ ] Panoya görsel gönderme Mac → Windows
- [ ] Menü çubuğu uygulaması + global kısayol ("Windows panosunu getir")
- [ ] Windows'ta çalışan uygulamalar / süreç listesi, kapatma
- [ ] Windows bildirimlerini Mac'e yansıtma

## v0.4 — Yayın
- [ ] İmzalı/notarize .dmg, GitHub Releases, Homebrew cask
- [ ] İngilizce yerelleştirme, README görselleri
- [ ] Sparkle ile otomatik güncelleme

## Fikirler
- Klasör senkronizasyonu (rsync benzeri, tek yön)
- Terminalde OSC 52 ile kopyalamayı yakalama
- Parola/anahtar yönetimi için Keychain entegrasyonu
