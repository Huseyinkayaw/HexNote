import Foundation

// MARK: - Not dosyası (yeniden başlatmada da korunur)

final class NoteStore {
    let dir: URL
    var file: URL { dir.appendingPathComponent("notes.txt") }

    /// Son başarılı kaydedilen metin; aynı metin tekrar diske yazılmaz.
    private(set) var lastSaved: String?

    init(dir: URL? = nil) {
        if let dir {
            self.dir = dir
        } else if let override = ProcessInfo.processInfo.environment["HEXNOTE_DIR"] {
            self.dir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.dir = base.appendingPathComponent("HexNote", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        // Klasör ve dosya yalnızca bu kullanıcı tarafından okunabilsin
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.dir.path)
        if FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }

    /// Notu okur. Dosya var ama okunamıyorsa (bozuk / UTF-8 değil) üzerine yazılmasın diye
    /// yedeğe taşınır ve boş başlanır — veri asla sessizce silinmez.
    func load() -> String {
        guard FileManager.default.fileExists(atPath: file.path) else { lastSaved = ""; return "" }
        do {
            let s = try String(contentsOf: file, encoding: .utf8)
            lastSaved = s
            return s
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = dir.appendingPathComponent("notes-okunamayan-\(stamp).txt")
            try? FileManager.default.moveItem(at: file, to: backup)
            lastSaved = nil
            return ""
        }
    }

    /// Değişiklik yoksa diske dokunmaz. Başarısızlıkta false döner.
    @discardableResult
    func save(_ text: String) -> Bool {
        if text == lastSaved { return true }
        do {
            try text.write(to: file, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            lastSaved = text
            return true
        } catch {
            NSLog("HexNote: kaydetme hatası: \(error)")
            return false
        }
    }
}

// MARK: - Girişte başlat (LaunchAgent)

struct LoginItem {
    static let label = "local.hexnote.launcher"
    let agentsDir: URL
    let appPath: String

    init(agentsDir: URL? = nil, appPath: String = Bundle.main.bundlePath) {
        if let agentsDir {
            self.agentsDir = agentsDir
        } else if let o = ProcessInfo.processInfo.environment["HEXNOTE_AGENTS_DIR"] {
            self.agentsDir = URL(fileURLWithPath: o, isDirectory: true)
        } else {
            self.agentsDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        }
        self.appPath = appPath
    }

    var plistURL: URL { agentsDir.appendingPathComponent("\(Self.label).plist") }
    var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    @discardableResult
    func set(_ on: Bool) -> Bool {
        if !on {
            if isEnabled { try? FileManager.default.removeItem(at: plistURL) }
            return !isEnabled
        }
        let plist: [String: Any] = [
            "Label": Self.label,
            // Argüman dizisi: kabuk yok, boşluklu yollar güvenli
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            return true
        } catch {
            NSLog("HexNote: LaunchAgent yazılamadı: \(error)")
            return false
        }
    }

    /// Uygulama taşındıysa kayıtlı yolu güncelle (yalnızca gerekiyorsa yazar).
    func refreshPathIfNeeded() {
        guard isEnabled,
              let d = NSDictionary(contentsOf: plistURL),
              let args = d["ProgramArguments"] as? [String] else { return }
        if args.last != appPath { set(true) }
    }
}
