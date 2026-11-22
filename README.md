# HexNote

A lightweight single-page **sticky note** that lives on your macOS desktop. Everything you type is saved automatically and survives restarts.

![HexNote](docs/screenshot.png)

## How to install & open
Requires macOS 13+ on an Apple Silicon Mac (M1 or later).

1. **[⬇ Download HexNote.dmg](https://github.com/Huseyinkayaw/HexNote/raw/main/release/HexNote.dmg)**
2. Open the DMG and drag **HexNote** into the **Applications** folder.
3. Open HexNote. Because the app is free and not notarized by Apple, macOS shows *"HexNote" Not Opened — Apple could not verify…*. Click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down to *"HexNote" was blocked…* and click **Open Anyway**, then enter your Mac password. You only need to do this once.

Prefer Terminal? Steps 3–4 can be replaced with:

```bash
xattr -dr com.apple.quarantine /Applications/HexNote.app
```

SHA-256 of the DMG: `38484ab71049c442a8e674b75c3e7c200e08f41f0c19c2e142c3220bc039b099`

## Features
- Auto-save (also saves before sleep and shutdown)
- Window layer: locked behind on the desktop, always on top, or normal
- Font size up/down (`⌘+` / `⌘-`), find (`⌘F`), copy the whole note
- Menu bar icon, launch at login, single-instance

## Privacy & security
- Makes no network connections.
- The note is stored only on this Mac in `~/Library/Application Support/HexNote` (readable only by your user account).

## Build from source
Requirements: macOS 13+, Xcode Command Line Tools.

```bash
./build.sh     # builds HexNote.app
./make-dmg.sh  # runs tests, builds and creates HexNote.dmg
```

---

## Türkçe

Masaüstünde duran tek sayfalık, hafif bir **yapışkan not** uygulaması. Yazdığınız her şey otomatik kaydedilir ve yeniden başlatmada korunur.

**Kurulum ve ilk açılış** (macOS 13+, Apple Silicon / M1 ve üstü)

1. **[⬇ HexNote.dmg dosyasını indirin](https://github.com/Huseyinkayaw/HexNote/raw/main/release/HexNote.dmg)**
2. DMG'yi açın ve **HexNote**'i **Uygulamalar** klasörüne sürükleyin.
3. HexNote'i açın. Uygulama ücretsiz olduğu ve Apple tarafından onaylanmadığı için macOS *"HexNote" Açılmadı — Apple … doğrulayamadı* uyarısı gösterir. **Bitti**'ye basın.
4. **Sistem Ayarları → Gizlilik ve Güvenlik**'i açın, aşağı inip *"HexNote" engellendi* satırındaki **Yine de Aç**'a tıklayın ve Mac şifrenizi girin. Bu yalnızca bir kez yapılır.

Terminal kullanıyorsanız 3–4. adımların yerine: `xattr -dr com.apple.quarantine /Applications/HexNote.app`

DMG SHA-256: `38484ab71049c442a8e674b75c3e7c200e08f41f0c19c2e142c3220bc039b099`

**Özellikler**
- Otomatik kayıt (uyku / kapanma öncesi de kaydeder)
- Pencere katmanı: masaüstünde arkada kilitli, her zaman üstte veya normal
- Yazı boyutu büyütme/küçültme (`⌘+` / `⌘-`), bulma (`⌘F`), tüm notu kopyalama
- Menü çubuğu simgesi, girişte başlatma, tek kopya çalışma

**Gizlilik ve güvenlik**
- İnternete bağlanmaz.
- Not yalnızca bu Mac'te, `~/Library/Application Support/HexNote` içinde durur (yalnızca sizin kullanıcınız okuyabilir).

**Kaynaktan derleme:** macOS 13+ ve Xcode Command Line Tools gerekir. `./build.sh` HexNote.app'i derler; `./make-dmg.sh` testleri çalıştırır, derler ve `HexNote.dmg` üretir.
