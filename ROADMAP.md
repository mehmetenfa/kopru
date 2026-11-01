# Yol haritası

## v0.1 — Temel (WSL2 hedefli; gerçek PC'de listeleme/pano/aktarım doğrulandı)
- [x] ~/.ssh/config'ten sunucu seçimi
- [x] Uzak klasör gezme, indirme/yükleme (sürükle-bırak), SHA-256 doğrulama
- [x] Pano: Windows → Mac (metin, görsel PNG), Mac → Windows (metin)
- [x] `kopru` CLI (ls/get/put/run/clip)

## PLAN: Her yön (Mac/Windows/Linux ↔ Mac/Windows/Linux) — kullanıcı istedi, karar bekliyor
İstenen: Mac→Windows, Windows→Mac, Mac→Linux, Windows→Linux (ve Mac→Mac). Önerilen sıra:

**Aşama 1 — Mac uygulaması, her hedef (v0.4)** ← önerilen ilk adım, tamamı bu Mac'ten test edilebilir
- [ ] Hedef işletim sistemi algılama (bağlanınca `uname` / `/proc/version`): WSL, Linux, macOS, Windows OpenSSH
- [ ] Hedef başına komut farkları: listeleme (`find -printf` GNU'ya özgü → macOS'ta `stat -f`), boyut (`du -sb` → macOS'ta `stat`/`du -sk`), boş alan (`df -B1 --output` → macOS `df -k`), doğrulama (`sha256sum` → macOS `shasum -a 256`), pano (macOS `pbcopy/pbpaste`, Linux `xclip/wl-copy`, WSL `powershell.exe`)
- [ ] Sade Windows OpenSSH hedefi: PowerShell ile listeleme/boyut/hash/pano (WSL'siz Windows)
- [ ] Rehbere "Mac" (Uzaktan Oturum'u aç) ve "Linux" (openssh-server) seçenekleri; `check` bu hedefleri tanısın
- [ ] Mac'te ikinci Mac/Linux olmadığı için gerçek test kullanıcıdan istenecek (birim testleri ile mantık sınanır)

**Aşama 2 — Windows istemcisi (Windows'tan Mac/Linux/Windows'a bağlanmak)** — KARAR BEKLİYOR
Üç seçenek sunuldu, kullanıcı henüz seçmedi ("sonra geliştirelim"):
1. (önerilen) Önce Aşama 1, Windows uygulaması sonra ayrı aşamada
2. Tek kod tabanı (Tauri: Rust + web arayüzü), Mac/Win/Linux tek uygulama — SwiftUI uygulaması bırakılır, Windows'ta masaüstüne sürükleyerek indirme zor
3. Mac uygulaması kalsın + ayrı yerel Windows uygulaması (C#/WinUI) — en çok emek, iki kod tabanı
Teknik notlar (Windows istemcisi için):
- Windows 10/11'de `ssh.exe` ve `scp.exe` var ama **rsync yok** → devam etme için rsync'siz motor gerek: indirmede `ssh host "tail -c +N dosya"` ile ofsetten akış, yüklemede uzak boyutu öğrenip `cat >> dosya` ile ekleme (hedef Unix ise); hash iki tarafta hesaplanır
- Win32-OpenSSH **ControlMaster/ControlPath (unix soket) desteklemez** → her komutta yeni bağlantı; bağlantı havuzu ya da kalıcı tek oturum üzerinden komut çalıştırma gerekir
- Windows ortamını bu Mac'ten test edemem; kullanıcının Windows PC'sine WSL üzerinden erişim var ama arayüz testi için kullanıcı denemeli

## v0.3.1 — Cihaz listesi + yeni bilgisayar rehberi (kodlandı, arayüz elle denenmedi; henüz yayınlanmadı)
- [x] "Yeni bilgisayar ekle" rehberi: Tailscale ya da aynı ağ yöntemi, kopyalanabilir komutlar, bağlantı tanılaması (Türkçe hata açıklamaları), kaydet ve bağlan
- [x] İlk bağlantıda sunucu anahtarı otomatik kabul (StrictHostKeyChecking=accept-new); `kopru <host> check`
- [x] ssh seçeneği gibi görünen adresler reddedilir (-o...)
- [x] Bağlanılan cihazlar kendiliğinden kaydedilir; bağlı değilken listede, her birinin yanında "Bağlan" düğmesi
- [x] Yeniden adlandır / listeden sil; son bağlantı zamanı; ~/.ssh/config sunucuları öneri olarak
- [x] Menü çubuğundan tek tıkla bağlan

## v0.3.0 — Yayınlandı
- [x] Menü çubuğu simgesi + menü (bağlan/kes, pano, durum)
- [x] Evrensel .app, DMG/ZIP, GitHub sürümü

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
- [ ] Apple Developer ID ile imza + notarize (Gatekeeper uyarısı kalksın), Homebrew cask
- [ ] İngilizce yerelleştirme, README görselleri
- [ ] Sparkle ile otomatik güncelleme

## Fikirler
- Klasör senkronizasyonu (rsync benzeri, tek yön)
- Terminalde OSC 52 ile kopyalamayı yakalama
- Parola/anahtar yönetimi için Keychain entegrasyonu
