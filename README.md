<p align="center"><img src="Resources/icon-1024.png" width="128" alt="Köprü logosu"></p>

# Köprü

Mac'ten SSH ile bağlandığınız Windows bilgisayardan **kayıpsız ve hızlı** dosya, pano ve komut çıktısı alın. Windows'a ek program kurmak gerekmez. Şu an hedef, SSH ile **WSL2** içine bağlanılan Windows bilgisayarlardır (ör. Tailscale SSH); doğrudan Windows OpenSSH desteği yol haritasında.

## İndir ve kur
1. [Releases](../../releases/latest) sayfasından `Kopru-x.y.z.dmg` dosyasını indir, aç, **Köprü**'yü Uygulamalar'a sürükle.
2. İlk açılışta macOS "doğrulanamadı" diyebilir (uygulama Apple ile imzalı/notarize değil). **Sağ tık → Aç → Aç** de ya da terminalde: `xattr -dr com.apple.quarantine /Applications/Köprü.app`
3. Sunucu kutusuna `kullanıcı@sunucu` yaz (Tailscale kullanıyorsan ör. `ad@pc-adi`) ve **Bağlan**'a bas.

Komut satırı aracı uygulamanın içinde: `ln -s "/Applications/Köprü.app/Contents/Resources/kopru" /usr/local/bin/kopru`

## Özellikler
- Windows klasörlerini gezin; **Finder gibi çoklu seçim** (⌘, ⇧, ⌘A), çift tıkla klasör aç
- Seçilenleri **masaüstüne/Finder'a sürükleyin** ya da toplu indirin; kayıt yerini siz seçersiniz
- Dosyaları pencereye (ya da bir klasörün üstüne) sürükleyip yükleyin
- Bayt bayt aynı aktarım, isteğe bağlı SHA-256 doğrulama
- Büyük dosyalar (GB'lar): ilerleme/hız/kalan süre, iptal, otomatik yeniden deneme, **kaldığı yerden devam**, boş alan kontrolü
- Windows panosunu Mac'e alın (metin, görsel PNG), Mac panosunu Windows'a gönderin
- **Menü çubuğu simgesi**: bağlantı durumu, pano kısayolları; pencere kapansa da çalışır
- `kopru` komut satırı: `kopru kullanici@pc run "ls -la" | pbcopy`

## Gereksinimler
- macOS 13+ (Apple Silicon ve Intel)
- Anahtar tabanlı (parolasız) SSH ile erişilen, **WSL2 kurulu** bir Windows PC (ör. Tailscale SSH). Doğrudan Windows OpenSSH desteği yol haritasında.
- WSL'de `rsync` ve `sha256sum` (genelde hazır gelir), Windows interop açık (varsayılan)
- Pano için Windows'ta oturum açık olmalı
- Mac'te hedef klasörde yeterli boş alan (uygulama başta kontrol eder)

## English
**Köprü** ("bridge") is a native macOS app that lets you browse a Windows PC you reach over SSH (currently via **WSL2**, e.g. Tailscale SSH) and move files and the clipboard **losslessly and fast**: Finder-style multi-select, drag to Desktop, batch download with a destination picker, resumable multi-GB transfers with progress, SHA-256 verification, menu bar icon and a `kopru` CLI. Download the DMG from [Releases](../../releases/latest). The UI is currently Turkish; localization is on the roadmap.

## Derleme
```
swift build
scripts/build-app.sh   # build/Köprü.app (evrensel)
scripts/make-dmg.sh    # dist/Kopru-x.y.z.dmg
```

## Durum
Erken aşama. Bkz. [ROADMAP.md](ROADMAP.md) ve [DURUM.md](DURUM.md). Hata bildirimleri için Issues.

## Lisans
MIT
