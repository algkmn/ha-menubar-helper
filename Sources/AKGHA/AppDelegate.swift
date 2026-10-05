import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let statusFontSize: CGFloat = 10
    private static let statusLineHeight: CGFloat = 10.5
    private static let statusBaselineOffset: CGFloat = -4.5
    private static let statusFontWeight: NSFont.Weight = .regular
    private static let statusIconSize: CGFloat = 12

    private var statusItems: [UUID: NSStatusItem] = [:]
    private var placeholderItem: NSStatusItem?
    private var timer: Timer?
    private var config: AppConfig?
    private var client: HAClient?
    private var hasData = false

    private let store = SettingsStore()
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if activateRunningInstance() {
            NSApp.terminate(nil)
            return
        }

        store.onSave = { [weak self] in self?.saveSettings() }
        store.onRefresh = { [weak self] in self?.refresh() }
        store.onQuit = { NSApp.terminate(nil) }
        store.onLaunchAtLoginChange = { enabled in
            if #available(macOS 13.0, *) {
                LoginItem.setEnabled(enabled)
            }
        }

        buildMainMenu()
        observeShowWindowRequests()
        AppConfig.writeTemplateIfMissing()
        reloadConfig()
        registerLoginItemIfFirstRun()
        refreshLoginItemState()
        refresh()

        if config?.isUsable != true {
            openSettings()
        }
    }

    private static let showWindowNotification = Notification.Name("com.algkmn.akgha.showWindow")

    private func activateRunningInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != current }
        guard let existing = others.first else { return false }
        existing.activate(options: [.activateAllWindows])
        DistributedNotificationCenter.default().postNotificationName(
            Self.showWindowNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return true
    }

    private func observeShowWindowRequests() {
        DistributedNotificationCenter.default().addObserver(
            forName: Self.showWindowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettings()
        }
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "HA Menubar Helper Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Pencereyi Kapat", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let quitItem = NSMenuItem(title: "Çıkış", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Düzen")
        editMenu.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Yinele", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func reloadConfig() {
        let loaded = AppConfig.load()
        config = loaded
        store.load(from: loaded ?? AppConfig.template)

        rebuildStatusItems()

        if let loaded, loaded.isUsable {
            client = HAClient(config: loaded)
            if !hasData { renderStatusItems([:]) }
            startTimer()
        } else {
            client = nil
            hasData = false
            timer?.invalidate()
            renderStatusItems([:], fallback: ("ayar", "yok"))
            store.status = "Sunucu adresi ve token gerekli"
        }
    }

    private func startTimer() {
        let interval = config?.resolvedPollInterval ?? AppConfig.defaultPollInterval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard let client, let sensors = config?.sensors.filter({ $0.isUsable }), !sensors.isEmpty else { return }
        Task { @MainActor in
            var results: [UUID: SensorSnapshot] = [:]
            await withTaskGroup(of: (UUID, SensorSnapshot).self) { group in
                for sensor in sensors {
                    group.addTask { (sensor.id, await client.snapshot(for: sensor)) }
                }
                for await (id, snapshot) in group {
                    results[id] = snapshot
                }
            }
            apply(results)
        }
    }

    @MainActor
    private func apply(_ snapshots: [UUID: SensorSnapshot]) {
        store.snapshots = snapshots
        let succeeded = snapshots.values.contains { $0.error == nil }
        hasData = hasData || succeeded

        renderStatusItems(snapshots, fallback: hasData ? nil : ("bağlantı", "yok"))

        if succeeded {
            store.status = "Güncellendi \(Format.time())"
        } else {
            let error = snapshots.values.compactMap(\.error).first ?? "bilinmeyen"
            store.status = "Bağlanamadı: \(error), \(Format.time())"
        }
    }

    private func rebuildStatusItems() {
        let sensors = config?.menuBarSensors ?? []
        let wanted = Set(sensors.map(\.id))

        for (id, item) in statusItems where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            statusItems[id] = nil
        }

        for sensor in sensors {
            let item = statusItems[sensor.id] ?? makeStatusItem(autosaveName: "akgha-\(sensor.id.uuidString)")
            item.button?.image = SensorIcons.image(named: sensor.icon, pointSize: Self.statusIconSize)
            item.button?.imagePosition = .imageLeading
            item.button?.toolTip = sensor.name
            statusItems[sensor.id] = item
        }

        if sensors.isEmpty {
            if placeholderItem == nil {
                placeholderItem = makeStatusItem(autosaveName: "akgha-placeholder")
                placeholderItem?.button?.image = SensorIcons.image(
                    named: SensorConfig.defaultIcon,
                    pointSize: Self.statusIconSize
                )
                placeholderItem?.button?.imagePosition = .imageLeading
            }
        } else if let placeholder = placeholderItem {
            NSStatusBar.system.removeStatusItem(placeholder)
            placeholderItem = nil
        }
    }

    private func makeStatusItem(autosaveName: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func renderStatusItems(_ snapshots: [UUID: SensorSnapshot], fallback: (String, String)? = nil) {
        for sensor in config?.menuBarSensors ?? [] {
            guard let button = statusItems[sensor.id]?.button else { continue }
            let snapshot = snapshots[sensor.id]
            let lines: (String, String)
            if snapshot == nil, let fallback {
                lines = fallback
            } else {
                lines = (
                    Format.temperature(snapshot?.temperature),
                    Format.humidity(snapshot?.humidity)
                )
            }
            button.attributedTitle = statusTitle(top: lines.0, bottom: lines.1)
        }

        if let button = placeholderItem?.button {
            let lines = fallback ?? (Format.placeholder, Format.placeholder)
            button.attributedTitle = statusTitle(top: lines.0, bottom: lines.1)
        }
    }

    private func statusTitle(top: String, bottom: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 0
        style.minimumLineHeight = Self.statusLineHeight
        style.maximumLineHeight = Self.statusLineHeight

        return NSAttributedString(
            string: top + "\n" + bottom,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: Self.statusFontSize,
                    weight: Self.statusFontWeight
                ),
                .paragraphStyle: style,
                .baselineOffset: Self.statusBaselineOffset,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func saveSettings() {
        let updated = store.makeConfig()
        do {
            try AppConfig.save(updated)
            store.flash("Kaydedildi \(Format.time())")
            reloadConfig()
            refresh()
        } catch {
            store.message = "Kaydedilemedi: \(Format.shortError(error))"
        }
    }

    @objc private func statusItemClicked() {
        openSettings()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: store)
        }
        refreshLoginItemState()
        settingsWindow?.present()
        refresh()
    }

    private func registerLoginItemIfFirstRun() {
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        if #available(macOS 13.0, *) {
            LoginItem.setEnabled(true)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private func refreshLoginItemState() {
        if #available(macOS 13.0, *) {
            store.setLaunchAtLoginWithoutSideEffect(LoginItem.isEnabled)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
