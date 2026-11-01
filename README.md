<p align="center"><img src="Resources/icon-1024.png" width="128" alt="Köprü logosu"></p>

# Köprü

Mac'ten SSH ile bağlandığınız Windows bilgisayardan **kayıpsız ve hızlı** dosya, pano ve komut çıktısı alın. Windows'a ek program kurmak gerekmez. Şu an hedef, SSH ile **WSL2** içine bağlanılan Windows bilgisayarlardır (ör. Tailscale SSH); doğrudan Windows OpenSSH desteği yol haritasında.

## Özellikler
- Windows klasörlerini gezin, dosya/klasör indirin, sürükle-bırak ile yükleyin
- Her tek dosya SHA-256 ile doğrulanır, bayt bayt aynıdır
- Windows panosunu Mac'e alın (metin, görseller PNG olarak sıkıştırmasız), Mac panosunu Windows'a gönderin
- `kopru` komut satırı: `kopru kullanici@pc run "ls -la" | pbcopy`

## Gereksinimler
- macOS 13+, anahtar tabanlı (parolasız) SSH ile erişilen, WSL2 kurulu bir Windows PC
- WSL'de `sha256sum` (varsayılan) ve Windows interop açık (varsayılan)
- Pano için Windows'ta oturum açık olmalı

## Derleme
```
swift build
scripts/build-app.sh   # build/Köprü.app
```

## Durum
Erken aşama (v0.1). Bkz. [ROADMAP.md](ROADMAP.md) ve [DURUM.md](DURUM.md).

## Lisans
MIT
