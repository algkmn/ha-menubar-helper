import AppKit
import SwiftUI

final class SettingsStore: ObservableObject {
    @Published var baseURL: String = ""
    @Published var token: String = ""
    @Published var pollInterval: String = "15"
    @Published var sensors: [SensorConfig] = []
    @Published var snapshots: [UUID: SensorSnapshot] = [:]
    @Published var message: String = ""
    @Published var status: String = ""
    @Published var launchAtLogin: Bool = false

    private var suppressLaunchAtLoginSideEffect = false
    private var flashToken = UUID()

    var onSave: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onQuit: (() -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?

    var statusLine: String {
        message.isEmpty ? status : message
    }

    func flash(_ text: String) {
        message = text
        let token = UUID()
        flashToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.flashToken == token else { return }
            self.message = ""
        }
    }

    func setLaunchAtLoginWithoutSideEffect(_ enabled: Bool) {
        guard launchAtLogin != enabled else { return }
        suppressLaunchAtLoginSideEffect = true
        launchAtLogin = enabled
        suppressLaunchAtLoginSideEffect = false
    }

    func launchAtLoginChanged(to enabled: Bool) {
        guard !suppressLaunchAtLoginSideEffect else { return }
        onLaunchAtLoginChange?(enabled)
    }

    func load(from config: AppConfig) {
        baseURL = config.baseURL
        token = config.token == AppConfig.placeholderToken ? "" : config.token
        pollInterval = String(format: "%.0f", config.resolvedPollInterval)
        sensors = config.sensors
    }

    func makeConfig() -> AppConfig {
        AppConfig(
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            pollInterval: Double(pollInterval) ?? AppConfig.defaultPollInterval,
            sensors: sensors.map {
                var sensor = $0
                sensor.name = sensor.name.trimmingCharacters(in: .whitespacesAndNewlines)
                sensor.temperatureEntity = sensor.temperatureEntity.trimmingCharacters(in: .whitespacesAndNewlines)
                sensor.humidityEntity = sensor.humidityEntity.trimmingCharacters(in: .whitespacesAndNewlines)
                if sensor.name.isEmpty {
                    sensor.name = SensorConfig.derivedName(from: sensor.temperatureEntity)
                }
                return sensor
            }
        )
    }

    func addSensor() {
        sensors.append(
            SensorConfig(name: "", temperatureEntity: "", humidityEntity: "", showInMenuBar: true)
        )
    }

    func removeSensor(_ id: UUID) {
        sensors.removeAll { $0.id == id }
        snapshots[id] = nil
    }
}

private struct IconPicker: View {
    @Binding var selection: String
    @State private var isPresented = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 9)

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: selection)
                .font(.system(size: 14))
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.bordered)
        .help("İkon seç")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Sembol ara", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(results, id: \.self) { name in
                                Button {
                                    selection = name
                                    isPresented = false
                                } label: {
                                    Image(systemName: name)
                                        .font(.system(size: 15))
                                        .frame(width: 30, height: 26)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(name == selection ? Color.accentColor.opacity(0.18) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(name)
                                .id(name)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(selection, anchor: .center)
                        searchFocused = true
                    }
                }
                .frame(height: 230)
                Text(results.isEmpty ? "Eşleşen sembol yok" : selection)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 340)
        }
    }

    private var results: [String] {
        SensorIcons.search(query)
    }
}

private struct ReadingCard: View {
    let sensor: SensorConfig
    let snapshot: SensorSnapshot?

    private var title: String {
        sensor.name.isEmpty ? "Adsız sensör" : sensor.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: sensor.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if sensor.showInMenuBar {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                        .help("Menü çubuğunda görünüyor")
                }
            }

            if let error = snapshot?.error {
                Text("—")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(.tertiary)
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Format.number(snapshot?.temperature?.state ?? "", decimals: 1))
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(snapshot?.temperature?.unit ?? "°C")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text("\(Format.humidity(snapshot?.humidity)) nem")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    sensor.showInMenuBar ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.09),
                    lineWidth: 1
                )
        )
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var tokenVisible = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    readings
                    sensorSection
                    connectionSection
                }
                .padding(20)
            }
            footer
        }
        .frame(minWidth: 700, minHeight: 520)
    }

    private var readings: some View {
        Group {
            if store.sensors.isEmpty {
                Text("Henüz sensör yok. Aşağıdan bir sensör ekleyip entity adlarını yaz.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(store.sensors) { sensor in
                        ReadingCard(sensor: sensor, snapshot: store.snapshots[sensor.id])
                    }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        store.sensors.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var sensorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sensörler")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    store.addSensor()
                } label: {
                    Label("Sensör ekle", systemImage: "plus")
                }
                .controlSize(.small)
            }
            Text("İşaretli sensörler menü çubuğunda kendi ikonlarıyla görünür.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !store.sensors.isEmpty {
                VStack(spacing: 0) {
                    ForEach($store.sensors) { $sensor in
                        sensorRow($sensor)
                        if sensor.id != store.sensors.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                )
                .padding(.top, 2)
            }
        }
    }

    private func sensorRow(_ sensor: Binding<SensorConfig>) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: sensor.showInMenuBar)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help("Menü çubuğunda göster")
            IconPicker(selection: sensor.icon)
            TextField("Ad", text: sensor.name)
                .frame(width: 215)
            VStack(spacing: 6) {
                TextField("sensor.xxx_temperature", text: sensor.temperatureEntity)
                TextField("sensor.xxx_humidity", text: sensor.humidityEntity)
            }
            Button {
                store.removeSensor(sensor.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Sensörü sil")
        }
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bağlantı")
                .font(.system(size: 15, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Sunucu").foregroundStyle(.secondary)
                    TextField("http://homeassistant.local:8123", text: $store.baseURL)
                }
                GridRow {
                    Text("Token").foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        if tokenVisible {
                            TextField("Uzun ömürlü erişim anahtarı", text: $store.token)
                        } else {
                            SecureField("Uzun ömürlü erişim anahtarı", text: $store.token)
                        }
                        Button(tokenVisible ? "Gizle" : "Göster") { tokenVisible.toggle() }
                            .controlSize(.small)
                    }
                }
                GridRow {
                    Text("Yenileme").foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("15", text: $store.pollInterval)
                            .frame(width: 56)
                            .monospacedDigit()
                        Text("saniyede bir").foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .font(.system(size: 13))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Text(store.statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button {
                    store.onRefresh?()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Şimdi güncelle")

                Spacer(minLength: 12)

                Toggle("Açılışta başlat", isOn: $store.launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .onChange(of: store.launchAtLogin) { enabled in
                        store.launchAtLoginChanged(to: enabled)
                    }
                Button("Çık") { store.onQuit?() }
                Button("Kaydet") { store.onSave?() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init(store: SettingsStore) {
        let hosting = NSHostingController(rootView: SettingsView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "HA Menubar Helper"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 720, height: 580))
        window.center()
        self.init(window: window)
        window.delegate = self
    }

    func present() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        guard let window else { return }

        let previousLevel = window.level
        window.level = .floating
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        }

        DispatchQueue.main.async {
            window.level = previousLevel
            window.makeFirstResponder(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
