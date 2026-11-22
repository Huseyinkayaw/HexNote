# HexNote

A lightweight single-page **sticky note** that lives on your macOS desktop. Everything you type is saved automatically and survives restarts.

![HexNote](docs/screenshot.png)

## Features
- Auto-save (also saves before sleep and shutdown)
- Window layer: locked behind on the desktop, always on top, or normal
- Font size up/down (`⌘+` / `⌘-`), find (`⌘F`), copy the whole note
- Menu bar icon, launch at login, single-instance

## Build & install
Requirements: macOS 13+, Xcode Command Line Tools.

```bash
./build.sh     # builds HexNote.app
./make-dmg.sh  # runs tests, builds and creates HexNote.dmg
```

---

## Türkçe

Masaüstünde duran tek sayfalık, hafif bir **yapışkan not** uygulaması. Yazdığınız her şey otomatik kaydedilir ve yeniden başlatmada korunur.

**Özellikler**
- Otomatik kayıt (uyku / kapanma öncesi de kaydeder)
- Pencere katmanı: masaüstünde arkada kilitli, her zaman üstte veya normal
- Yazı boyutu büyütme/küçültme (`⌘+` / `⌘-`), bulma (`⌘F`), tüm notu kopyalama
- Menü çubuğu simgesi, girişte başlatma, tek kopya çalışma

**Kurulum:** macOS 13+ ve Xcode Command Line Tools gerekir. `./build.sh` HexNote.app'i derler; `./make-dmg.sh` testleri çalıştırır, derler ve `HexNote.dmg` üretir.
