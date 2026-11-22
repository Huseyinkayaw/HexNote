import Foundation

// Basit test koşucusu: swiftc Core.swift Tests/tests.swift -o /tmp/x && /tmp/x
var failures = 0
var passed = 0
func check(_ cond: Bool, _ name: String, file: String = #file, line: Int = #line) {
    if cond { passed += 1 } else { failures += 1; print("❌ \(name) (satır \(line))") }
}
func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("hexnote-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}
func perms(_ path: String) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int) ?? -1
}
func mtime(_ url: URL) -> Date? {
    try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
}

// 1. İlk açılış: dosya yok → boş, hata yok
do {
    let s = NoteStore(dir: tempDir())
    check(s.load() == "", "ilk açılışta boş not")
}

// 2. Kaydet / yeniden aç (yeniden başlatma simülasyonu) + Türkçe / emoji / satır sonları
do {
    let d = tempDir()
    let text = "Şçğüöı İ ÇĞÜÖ 🙂👍\nsatır 2\r\nsatır 3\t sekme\n\n"
    check(NoteStore(dir: d).save(text), "kaydetme başarılı")
    check(NoteStore(dir: d).load() == text, "yeniden açınca aynı metin (unicode)")
}

// 3. İzinler: klasör 700, dosya 600 (başka kullanıcılar okuyamaz)
do {
    let d = tempDir()
    let s = NoteStore(dir: d)
    s.save("gizli")
    check(perms(d.path) == 0o700, "klasör izni 700")
    check(perms(s.file.path) == 0o600, "dosya izni 600")
    // Eski sürümden kalan 644 dosya düzeltiliyor mu
    try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: s.file.path)
    _ = NoteStore(dir: d)
    check(perms(s.file.path) == 0o600, "eski 644 dosya 600'e çekildi")
}

// 4. Gereksiz yazma yok: aynı metin diske tekrar yazılmaz
do {
    let s = NoteStore(dir: tempDir())
    s.save("abc")
    let t1 = mtime(s.file)
    Thread.sleep(forTimeInterval: 1.1)
    s.save("abc")
    check(mtime(s.file) == t1, "değişmeyen metin yeniden yazılmadı")
    s.save("abcd")
    check(mtime(s.file) != t1, "değişen metin yazıldı")
    // açılışta yüklenen metinle aynıysa da yazılmaz
    let s2 = NoteStore(dir: s.dir); _ = s2.load()
    let t2 = mtime(s.file)
    Thread.sleep(forTimeInterval: 1.1)
    s2.save("abcd")
    check(mtime(s.file) == t2, "açılıştan sonra değişiklik yoksa yazma yok")
}

// 5. Bozuk dosya: silinmez, yedeğe alınır
do {
    let d = tempDir()
    let s = NoteStore(dir: d)
    let bad = Data([0xFF, 0xFE, 0x00, 0xC3, 0x28, 0x80])
    try! bad.write(to: s.file)
    check(s.load() == "", "bozuk dosyada boş başlar")
    let files = try! FileManager.default.contentsOfDirectory(atPath: d.path)
    let backup = files.first { $0.hasPrefix("notes-okunamayan-") }
    check(backup != nil, "bozuk dosya yedeklendi")
    if let backup { check((try? Data(contentsOf: d.appendingPathComponent(backup))) == bad, "yedek içeriği aynen korundu") }
    s.save("yeni")
    check(s.load() == "yeni", "yedekten sonra yeni not çalışıyor")
}

// 6. Yazılamayan klasör: çökmez, false döner
do {
    let d = tempDir()
    let s = NoteStore(dir: d)
    try! FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: d.path)
    check(s.save("x") == false, "yazılamayan klasörde save false döner")
    try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: d.path)
    check(s.save("x") == true, "izin gelince tekrar kaydeder")
}

// 7. Atomik yazma: yarım dosya kalmaz, geçici dosya artığı yok
do {
    let d = tempDir()
    let s = NoteStore(dir: d)
    for i in 0..<200 { s.save(String(repeating: "x", count: i * 50)) }
    let files = try! FileManager.default.contentsOfDirectory(atPath: d.path)
    check(files == ["notes.txt"], "200 kayıttan sonra yalnızca notes.txt var (\(files))")
    check(s.load().count == 199 * 50, "son sürüm tam olarak duruyor")
}

// 8. Performans: 5 MB not kaydet / yükle
do {
    let s = NoteStore(dir: tempDir())
    let big = String(repeating: "Merhaba dünya, bu bir performans testi. 🙂\n", count: 120_000)
    var t = Date()
    s.save(big)
    let saveMs = Date().timeIntervalSince(t) * 1000
    t = Date()
    let back = NoteStore(dir: s.dir).load()
    let loadMs = Date().timeIntervalSince(t) * 1000
    check(back == big, "büyük not birebir geri geldi")
    print(String(format: "   %.1f MB kaydet: %.0f ms, yükle: %.0f ms", Double(big.utf8.count) / 1e6, saveMs, loadMs))
    check(saveMs < 500 && loadMs < 500, "5 MB kaydet/yükle 500 ms altında")
}

// 9. Girişte başlat plist'i: geçerli, boşluklu yol güvenli, aç/kapa çalışıyor
do {
    let agents = tempDir().appendingPathComponent("LaunchAgents")
    let path = "/Applications/Benim Uygulamalarım/HexNote.app"
    let li = LoginItem(agentsDir: agents, appPath: path)
    check(!li.isEnabled, "başta kapalı")
    check(li.set(true) && li.isEnabled, "açılabiliyor")
    let d = NSDictionary(contentsOf: li.plistURL)
    let args = d?["ProgramArguments"] as? [String]
    check(args == ["/usr/bin/open", "-a", path], "argümanlar ayrık, kabuk yok")
    check(d?["RunAtLoad"] as? Bool == true, "RunAtLoad true")
    let lint = Process()
    lint.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
    lint.arguments = ["-lint", "-s", li.plistURL.path]
    try! lint.run(); lint.waitUntilExit()
    check(lint.terminationStatus == 0, "plutil -lint geçti")
    // Uygulama taşınınca yol güncellenir
    let moved = LoginItem(agentsDir: agents, appPath: "/Applications/HexNote.app")
    moved.refreshPathIfNeeded()
    check((NSDictionary(contentsOf: li.plistURL)?["ProgramArguments"] as? [String])?.last == "/Applications/HexNote.app", "taşınınca yol güncellendi")
    check(li.set(false) && !li.isEnabled, "kapatılabiliyor")
    check(li.set(false), "zaten kapalıyken kapatmak hata vermez")
}

print("\n\(passed) geçti, \(failures) başarısız")
exit(failures == 0 ? 0 : 1)
