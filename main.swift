import AppKit

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSWindowDelegate, NSMenuDelegate, NSMenuItemValidation {
    var window: NSWindow!
    var textView: NSTextView!
    var saveTimer: Timer?
    var statusItem: NSStatusItem!
    let defaults = UserDefaults.standard
    let store = NoteStore()
    let loginItem = LoginItem()
    var saveErrorShown = false
    static let showNotification = Notification.Name("local.hexnote.show")

    /// Pencere katman kilidi
    enum PinMode: String { case back, top, none }

    var pinMode: PinMode {
        // Varsayılan: arkada kilitli (masaüstü notu gibi)
        get { PinMode(rawValue: defaults.string(forKey: "pinMode") ?? "") ?? .back }
        set { defaults.set(newValue.rawValue, forKey: "pinMode"); applyFloating() }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        // Tek kopya: iki HexNote aynı dosyaya yazıp birbirinin notunu ezmesin
        let me = NSRunningApplication.current
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != me.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(Self.showNotification, object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showWindow),
                                                            name: Self.showNotification, object: nil)
        // Kapanma / oturum kapatma öncesi son kayıt
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(saveNowObjc),
                                                          name: NSWorkspace.willPowerOffNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(saveNowObjc),
                                                          name: NSWorkspace.willSleepNotification, object: nil)
        loginItem.refreshPathIfNeeded()
        NSApp.setActivationPolicy(.accessory)   // Dock'ta yok, sadece menü çubuğunda
        buildMainMenu()
        buildStatusItem()
        buildWindow()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return true
    }

    func applicationWillTerminate(_ note: Notification) { saveNow() }

    // MARK: Window

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 40, y: 120, width: 440, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "HexNote"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 200, height: 150)
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFrameAutosaveName("HexNoteMainWindow")   // boyut/konum hatırlanır

        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        textView = (scroll.documentView as! NSTextView)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.systemFont(ofSize: CGFloat(fontSize))
        textView.textContainerInset = NSSize(width: 14, height: 34)
        textView.string = store.load()
        textView.delegate = self

        window.contentView = scroll
        addLockButton()
        applyFloating()
        window.makeFirstResponder(textView)
    }

    @objc func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc func toggleWindow() {
        // Menüdeki etiketle aynı mantık: görünüyorsa gizle, değilse göster
        if window.isVisible { saveNow(); window.orderOut(nil) } else { showWindow() }
    }

    func windowDidResignKey(_ note: Notification) { saveNow() }

    // MARK: Otomatik kayıt

    func textDidChange(_ note: Notification) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in self?.saveNow() }
    }

    @objc func saveNowObjc() { saveNow() }

    func saveNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        guard let tv = textView else { return }
        if !store.save(tv.string) && !saveErrorShown {
            saveErrorShown = true
            let a = NSAlert()
            a.alertStyle = .warning
            a.messageText = "Not kaydedilemedi"
            a.informativeText = "Disk dolu olabilir veya klasöre yazılamıyor:\n\(store.file.path)\nYazdıkların pencerede duruyor; ⇧⌘C ile kopyalayıp güvenceye alabilirsin."
            a.runModal()
        }
    }

    // MARK: Yazı boyutu

    var fontSize: Int {
        get { let v = defaults.integer(forKey: "fontSize"); return v == 0 ? 14 : v }
        set { defaults.set(newValue, forKey: "fontSize"); textView?.font = NSFont.systemFont(ofSize: CGFloat(newValue)) }
    }
    @objc func biggerFont() { fontSize = min(fontSize + 1, 40) }
    @objc func smallerFont() { fontSize = max(fontSize - 1, 9) }

    // MARK: Ayar eylemleri

    @objc func pinBack() { pinMode = pinMode == .back ? .none : .back }
    @objc func pinTop()  { pinMode = pinMode == .top ? .none : .top }
    @objc func pinNone() { pinMode = .none }

    // MARK: Katman kilidi (başlık çubuğundaki kilit düğmesi)

    var lockButton: NSButton!

    func addLockButton() {
        lockButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 22))
        lockButton.bezelStyle = .accessoryBarAction
        lockButton.isBordered = false
        lockButton.imagePosition = .imageOnly
        lockButton.target = self
        lockButton.action = #selector(showLockMenu)
        let holder = NSView(frame: NSRect(x: 0, y: 0, width: 38, height: 22))
        holder.addSubview(lockButton)
        let acc = NSTitlebarAccessoryViewController()
        acc.view = holder
        acc.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(acc)
    }

    func lockMenuItems() -> [NSMenuItem] {
        let items: [(String, Selector, PinMode, String)] = [
            ("Arkada Kilitle (masaüstünde dursun)", #selector(pinBack), .back, "b"),
            ("Üstte Kilitle (her zaman önde)", #selector(pinTop), .top, "t"),
            ("Kilit Yok (normal pencere)", #selector(pinNone), .none, ""),
        ]
        return items.map { title, sel, mode, key in
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.keyEquivalentModifierMask = [.command, .shift]
            i.target = self
            i.state = pinMode == mode ? .on : .off
            return i
        }
    }

    @objc func showLockMenu() {
        let m = NSMenu()
        lockMenuItems().forEach { m.addItem($0) }
        m.popUp(positioning: nil, at: NSPoint(x: 0, y: lockButton.bounds.height + 4), in: lockButton)
    }

    func applyFloating() {
        guard let w = window else { return }
        w.hidesOnDeactivate = false   // başka uygulamaya geçince gizlenmesin
        switch pinMode {
        case .back:
            // Duvar kâğıdı ve masaüstü simgelerinin hemen üstü: her uygulama önüne geçer,
            // ama not hep orada durur; tıklayıp yazabilirsin. "Masaüstünü göster"de de yerinde kalır.
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        case .top:
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .none:
            w.level = .normal
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        guard let b = lockButton else { return }
        let (sym, tint, tip): (String, NSColor, String) = {
            switch pinMode {
            case .back: return ("lock.fill", .controlAccentColor, "Arkada kilitli — masaüstünde duruyor. Değiştirmek için tıkla.")
            case .top:  return ("pin.fill", .systemOrange, "Üstte kilitli — her zaman önde. Değiştirmek için tıkla.")
            case .none: return ("lock.open", .secondaryLabelColor, "Kilit yok — normal pencere. Değiştirmek için tıkla.")
            }
        }()
        b.image = NSImage(systemSymbolName: sym, accessibilityDescription: tip)
        b.contentTintColor = tint
        b.toolTip = tip
    }

    @objc func toggleLogin() {
        if !loginItem.set(!loginItem.isEnabled) {
            let a = NSAlert(); a.messageText = "Girişte başlat ayarı değiştirilemedi"; a.runModal()
        }
    }

    @objc func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc func clearAll() {
        showWindow()
        let a = NSAlert()
        a.messageText = "Tüm not silinsin mi?"
        a.informativeText = "Geri almak için ⌘Z kullanabilirsin."
        a.addButton(withTitle: "Temizle")
        a.addButton(withTitle: "Vazgeç")
        if a.runModal() == .alertFirstButtonReturn {
            textView.selectAll(nil)
            textView.insertText("", replacementRange: textView.selectedRange())
            saveNow()
        }
    }

    @objc func revealNotesFile() { saveNow(); NSWorkspace.shared.activateFileViewerSelecting([store.file]) }

    // MARK: Menü çubuğu simgesi (üstte)

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "HexNote")
            b.image?.isTemplate = true
        }
        let m = NSMenu()
        m.delegate = self
        statusItem.menu = m
    }

    // Menü her açıldığında güncel tik durumlarıyla yeniden kurulur
    func menuNeedsUpdate(_ m: NSMenu) {
        m.removeAllItems()
        func add(_ title: String, _ sel: Selector, _ key: String = "", on: Bool? = nil) {
            let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key)
            i.target = self
            if let on { i.state = on ? .on : .off }
        }
        let visible = window.isVisible
        add(visible ? "Notu Gizle" : "Notu Göster", #selector(toggleWindow))
        add("Tüm Notu Kopyala", #selector(copyAll))
        m.addItem(.separator())

        let header = m.addItem(withTitle: "Ayarlar", action: nil, keyEquivalent: "")
        header.isEnabled = false
        add("Girişte Başlat", #selector(toggleLogin), on: loginItem.isEnabled)
        lockMenuItems().forEach { $0.keyEquivalent = ""; m.addItem($0) }
        add("Yazıyı Büyüt", #selector(biggerFont))
        add("Yazıyı Küçült", #selector(smallerFont))
        m.addItem(.separator())
        add("Not Dosyasını Finder'da Göster", #selector(revealNotesFile))
        add("Notu Temizle…", #selector(clearAll))
        m.addItem(.separator())
        let q = m.addItem(withTitle: "HexNote'tan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        q.target = NSApp
    }

    // MARK: Uygulama menüsü (kısayollar için)

    func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        let login = appMenu.addItem(withTitle: "Girişte Başlat", action: #selector(toggleLogin), keyEquivalent: ""); login.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "HexNote'u Gizle", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "HexNote'tan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Düzen")
        edit.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Yinele", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Yapıştır", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        let ca = edit.addItem(withTitle: "Tüm Notu Kopyala", action: #selector(copyAll), keyEquivalent: "c")
        ca.keyEquivalentModifierMask = [.command, .shift]; ca.target = self
        let clear = edit.addItem(withTitle: "Notu Temizle…", action: #selector(clearAll), keyEquivalent: ""); clear.target = self
        edit.addItem(.separator())
        let find = edit.addItem(withTitle: "Bul…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        editItem.submenu = edit

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: "Görünüm")
        let big = view.addItem(withTitle: "Yazıyı Büyüt", action: #selector(biggerFont), keyEquivalent: "+"); big.target = self
        let small = view.addItem(withTitle: "Yazıyı Küçült", action: #selector(smallerFont), keyEquivalent: "-"); small.target = self
        view.addItem(.separator())
        lockMenuItems().forEach { view.addItem($0) }
        viewItem.submenu = view

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Pencere")
        win.addItem(withTitle: "Kapat", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        win.addItem(withTitle: "Küçült", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let show = win.addItem(withTitle: "Notu Göster", action: #selector(showWindow), keyEquivalent: "1"); show.target = self
        winItem.submenu = win
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }

    // Menüdeki tik işaretleri
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleLogin): item.state = loginItem.isEnabled ? .on : .off
        case #selector(pinBack): item.state = pinMode == .back ? .on : .off
        case #selector(pinTop): item.state = pinMode == .top ? .on : .off
        case #selector(pinNone): item.state = pinMode == .none ? .on : .off
        default: break
        }
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
