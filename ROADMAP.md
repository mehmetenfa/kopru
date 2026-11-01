# Yol haritası

## v0.1 — Temel (WSL2 hedefli; gerçek PC'de listeleme/pano/aktarım doğrulandı)
- [x] ~/.ssh/config'ten sunucu seçimi
- [x] Uzak klasör gezme, indirme/yükleme (sürükle-bırak), SHA-256 doğrulama
- [x] Pano: Windows → Mac (metin, görsel PNG), Mac → Windows (metin)
- [x] `kopru` CLI (ls/get/put/run/clip)

## v0.2.1 — Dosya yöneticisi hissi (kodlandı, elle denenmedi)
- [x] Bağlantıyı kes düğmesi (kalıcı ssh bağlantısı kapanır; uygulama kapanınca da kapanır)
- [x] Finder gibi çoklu seçim (tıkla, ⌘ tıkla, ⇧ tıkla, ⌘A), çift tıkla/Return klasör aç
- [x] Seçilenleri masaüstüne/Finder'a sürükle-bırak (bırakınca indirilir)
- [x] Seçilenleri toplu indir; kayıt yeri seçimi (Masaüstü/İndirilenler/Belgeler/başka klasör, "her seferinde sor")
- [x] Sağ tık menüsü; klasörün üstüne dosya bırakınca o klasöre yükle

## v0.2 — Hız ve güven
- [x] İlerleme çubuğu + hız + kalan süre, iptal, Mac uykuya geçmesin
- [x] Kesilen aktarımı sürdürme (rsync --append, ara klasör .kopru-partial), otomatik yeniden deneme (6 deneme)
- [x] Boş alan kontrolü (Mac ve Windows tarafı), ad çakışmasında "ad (2)"
- [ ] Aktarım kuyruğu (şimdilik tek seferde bir aktarım)
- [ ] Büyük klasörlerde tek tar akışı (çok sayıda küçük dosya için hızlı)
- [ ] Klasörler için hash doğrulaması
- [ ] Doğrudan Windows OpenSSH (WSL'siz) arka ucu: PowerShell tabanlı listeleme/pano
- [ ] Tailscale SSH ilk kimlik doğrulama bağlantısını uygulamada göster
- [ ] Uygulama arayüzünü gerçek kullanımda test et (şu an yalnızca CLI doğrulandı)

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
