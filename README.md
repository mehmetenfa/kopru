<p align="center"><img src="Resources/icon-1024.png" width="128" alt="Köprü logosu"></p>

# Köprü

Mac'ten SSH ile bağlandığınız Windows bilgisayardan **kayıpsız ve hızlı** dosya, pano ve komut çıktısı alın. Windows'a ek program kurmak gerekmez; yalnızca OpenSSH Server yeterlidir.

## Özellikler
- Windows klasörlerini gezin, dosya/klasör indirin, sürükle-bırak ile yükleyin
- Her tek dosya SHA-256 ile doğrulanır, bayt bayt aynıdır
- Windows panosunu Mac'e alın (metin, görseller PNG olarak sıkıştırmasız), Mac panosunu Windows'a gönderin
- `kopru` komut satırı: `kopru win run "Get-Process" | pbcopy`

## Gereksinimler
- macOS 13+, `~/.ssh/config` içinde anahtar tabanlı giriş ayarlı bir Windows sunucusu
- Windows'ta OpenSSH Server ve (pano için) açık kullanıcı oturumu

## Derleme
```
swift build
scripts/build-app.sh   # build/Köprü.app
```

## Durum
Erken aşama (v0.1). Bkz. [ROADMAP.md](ROADMAP.md) ve [DURUM.md](DURUM.md).

## Lisans
MIT
