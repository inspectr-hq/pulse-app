import SwiftUI
import AppKit

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case menuBar = "Menu Bar"
        case webhooks = "Webhooks"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .menuBar: return "menubar.rectangle"
            case .webhooks: return "link"
            }
        }
    }
    
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedTab: Tab = .general
    @State private var selectedWebhookID: UUID?
    private let compactWindowSize = NSSize(width: 720, height: 620)
    private let webhooksWindowSize = NSSize(width: 840, height: 760)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 22, weight: .regular))
                                Text(tab.rawValue)
                                    .font(.system(size: 13))
                            }
                        }
                        .frame(width: 98, height: 68)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                resizeWindow(for: newTab)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .menuBar:
                        menuBarTab
                    case .webhooks:
                        webhooksTab
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 620)
        .frame(
            minWidth: selectedTab == .webhooks ? webhooksWindowSize.width : compactWindowSize.width,
            minHeight: selectedTab == .webhooks ? webhooksWindowSize.height : compactWindowSize.height
        )
        .onDisappear { vm.saveSettings() }
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsToggleRow("Startup:", title: "Start at login", isOn: $vm.settings.launchAtLogin)
            settingsToggleRow("Dock:", title: "Show alert badge", isOn: $vm.settings.showAlertBadgeOnDockIcon)
            
            Divider()
                .frame(width: 427)
                .frame(maxWidth: .infinity, alignment: .center)
            
            alignedRow("Check Interval:") {
                HStack(spacing: 8) {
                    TextField("900", value: $vm.settings.pingIntervalSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }
            
            alignedRow("Auto Checks:") {
                Picker("", selection: $vm.settings.pausePingWhen) {
                    Text("Pause when offline").tag(PausePingMode.offline)
                    Text("Always run").tag(PausePingMode.never)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180, alignment: .leading)
                .help("Controls whether automatic scheduler checks are paused when your Mac is offline. Manual checks always run.")
            }
            
            alignedRow("Delay Checks:") {
                HStack(spacing: 8) {
                    TextField("0", value: $vm.settings.staggerRequestsSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("seconds between sites")
                        .foregroundStyle(.secondary)
                }
                .help("Adds delay between checks during batch runs to reduce burst traffic and rate-limit pressure.")
            }
            
            alignedRow("Failures to Alert:") {
                Stepper(value: $vm.settings.failuresToAlert, in: 1...20) {
                    Text("\(vm.settings.failuresToAlert) consecutive")
                }
                .frame(width: 220, alignment: .leading)
            }

            alignedRow("History Retention:") {
                Picker("", selection: $vm.settings.historyRetentionPolicy) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(policy.label).tag(policy)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180, alignment: .leading)
                .help("Automatically removes older history events using a rolling time window.")
            }

            Divider()
                .frame(width: 427)
                .frame(maxWidth: .infinity, alignment: .center)
            
            alignedRow("Default Threshold:") {
                HStack(spacing: 8) {
                    TextField("2000", value: $vm.settings.defaultThresholdMs, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
            }
            
            alignedRow("Default Method:") {
                Picker("", selection: $vm.settings.defaultMethod) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120, alignment: .leading)
            }
        }
        .padding(.top, 6)
    }
    
    private var menuBarTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            alignedRow("Menu Items:") {
                Stepper(value: $vm.settings.menuMaxItems, in: 1...200) {
                    Text("Max \(vm.settings.menuMaxItems)")
                }
                .frame(width: 220, alignment: .leading)
            }
            
            settingsToggleRow("Menu Icon:", title: "Show status color", isOn: $vm.settings.showMenuIconStatusColor)
            
            alignedRow("Colorize Icon:") {
                Picker("", selection: $vm.settings.menuBarIconColorMode) {
                    Text("Always").tag(MenuBarIconColorMode.always)
                    Text("Only failing").tag(MenuBarIconColorMode.onlyWhenFailing)
                    Text("Never").tag(MenuBarIconColorMode.never)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 220, alignment: .leading)
                .disabled(!vm.settings.showMenuIconStatusColor)
            }
            
            Divider()
                .frame(width: 400)
                .padding(.leading, 80)
            
            settingsToggleRow("Method:", title: "Show method", isOn: $vm.settings.showMethodInMenu)
            settingsToggleRow("Response Time:", title: "Show response time", isOn: $vm.settings.showResponseTimeInMenu)
            settingsToggleRow("Last Checked:", title: "Show last checked", isOn: $vm.settings.showLastCheckedInMenu)
            settingsToggleRow("Status Code:", title: "Show status code", isOn: $vm.settings.showStatusCodeInMenu)
            settingsToggleRow("Paused Sites:", title: "Hide paused sites in menu bar", isOn: $vm.settings.hidePausedSitesInMenuBar)

            Divider()
                .frame(width: 400)
                .padding(.leading, 80)

            alignedRow("Status Colors:") {
                VStack(alignment: .leading, spacing: 10) {
                    statusColorPickerRow("Up", color: Binding(
                        get: { vm.settings.statusColorUp.color },
                        set: { vm.settings.statusColorUp = codableColor(from: $0, fallback: vm.settings.statusColorUp) }
                    ))
                    statusColorPickerRow("Slow", color: Binding(
                        get: { vm.settings.statusColorSlow.color },
                        set: { vm.settings.statusColorSlow = codableColor(from: $0, fallback: vm.settings.statusColorSlow) }
                    ))
                    statusColorPickerRow("Failure", color: Binding(
                        get: { vm.settings.statusColorFailure.color },
                        set: { vm.settings.statusColorFailure = codableColor(from: $0, fallback: vm.settings.statusColorFailure) }
                    ))
                    statusColorPickerRow("Offline", color: Binding(
                        get: { vm.settings.statusColorOffline.color },
                        set: { vm.settings.statusColorOffline = codableColor(from: $0, fallback: vm.settings.statusColorOffline) }
                    ))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }
    
    private var webhooksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                webhookOverviewPane

                Divider()
                    .frame(maxHeight: .infinity)

                webhookEditorPane
            }
        }
        .padding(.top, 8)
        .onAppear {
            if selectedWebhookID == nil {
                selectedWebhookID = vm.settings.webhookConfigs.first?.id
            }
        }
    }

    private var webhookOverviewPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text("Webhooks")
                    .font(.headline)

                Spacer(minLength: 8)

                Button {
                    addWebhookRule()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("Add webhook rule")

                Button {
                    removeSelectedWebhookRule()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(selectedWebhookIndex == nil)
                .help("Remove selected webhook rule")
            }
            .padding(.horizontal, 2)

            Group {
                if vm.settings.webhookConfigs.isEmpty {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No webhook rules yet")
                            .font(.headline)
                        Text("Use webhooks to send alerts to your own systems, chat tools, or automation services when a site goes down or recovers.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Create webhook rule") {
                            addWebhookRule()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                } else {
                    List(selection: $selectedWebhookID) {
                        ForEach(vm.settings.webhookConfigs) { config in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(config.name)
                                    .fontWeight(selectedWebhookID == config.id ? .semibold : .regular)
                                Text("\(config.sendOn.rawValue) • \(config.scope.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(Optional(config.id))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 300, height: 320)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .frame(minWidth: 240, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
    }

    private var webhookEditorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Webhook Form")
                .font(.headline)

            if let configBinding = selectedWebhookConfigBinding {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        alignedRow("Rule Name:") {
                            TextField("Webhook", text: Binding(
                                get: { configBinding.wrappedValue.name },
                                set: { configBinding.wrappedValue.name = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        alignedRow("Send On:") {
                            Picker("", selection: Binding(
                                get: { configBinding.wrappedValue.sendOn },
                                set: { configBinding.wrappedValue.sendOn = $0 }
                            )) {
                                ForEach(WebhookSendOn.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 220, alignment: .leading)
                        }

                        webhookSiteFilterRow(config: configBinding)

                        alignedRow("Webhook URL:") {
                            TextField("https://example.com/webhook", text: Binding(
                                get: { configBinding.wrappedValue.url },
                                set: { configBinding.wrappedValue.url = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        alignedRow("Method:") {
                            Picker("", selection: Binding(
                                get: { configBinding.wrappedValue.method },
                                set: { configBinding.wrappedValue.method = $0 }
                            )) {
                                Text("POST").tag(HTTPMethod.post)
                                Text("GET").tag(HTTPMethod.get)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 120, alignment: .leading)
                        }
                        alignedRow("Payload:") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextEditor(text: Binding(
                                    get: { configBinding.wrappedValue.payloadTemplate },
                                    set: { configBinding.wrappedValue.payloadTemplate = $0 }
                                ))
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 140)
                                .padding(6)
                                .background(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                )
                                HStack {
                                    Button("Format JSON") { formatWebhookPayloadJSON(config: configBinding) }
                                        .buttonStyle(.bordered)
                                    Spacer()
                                }
                            }
                        }
                        alignedRow("Retries:") {
                            Stepper(value: Binding(
                                get: { configBinding.wrappedValue.maxRetries },
                                set: { configBinding.wrappedValue.maxRetries = $0 }
                            ), in: 0...8) {
                                Text("\(configBinding.wrappedValue.maxRetries)")
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                        alignedRow("Initial Backoff:") {
                            HStack(spacing: 8) {
                                TextField("1.0", value: Binding(
                                    get: { configBinding.wrappedValue.initialBackoffSeconds },
                                    set: { configBinding.wrappedValue.initialBackoffSeconds = $0 }
                                ), format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("seconds")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        alignedRow("Placeholders:") {
                            Text("$MESSAGE, $MONITOR, $STATUS, $URL, $TRIGGER, $STATUS_CODE, $RESPONSE_MS, $TIMESTAMP")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, 8)
                }
            } else {
                Text("Select a webhook rule to edit it.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    @ViewBuilder
    private func settingsToggleRow(_ label: String, title: String, isOn: Binding<Bool>) -> some View {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .fontWeight(.none)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
                Toggle(title, isOn: isOn)
                    .toggleStyle(.checkbox)
                    .frame(width: 305, alignment: .leading)
            }
        .frame(width: 477, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private func alignedRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                content()
                    .frame(width: 305, alignment: .leading)
            }
        .frame(width: 477, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private func statusColorPickerRow(_ label: String, color: Binding<Color>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 54, alignment: .leading)
                .foregroundStyle(.secondary)
            ColorPicker("", selection: color, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 44, alignment: .leading)
        }
    }
    
    private func codableColor(from color: Color, fallback: CodableColor) -> CodableColor {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.deviceRGB) else { return fallback }
        return CodableColor(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
    }

    private var selectedWebhookIndex: Int? {
        guard let selectedWebhookID else { return nil }
        return vm.settings.webhookConfigs.firstIndex(where: { $0.id == selectedWebhookID })
    }

    private var selectedWebhookConfigBinding: Binding<WebhookConfig>? {
        guard let selectedWebhookID else { return nil }
        return Binding(
            get: {
                vm.settings.webhookConfigs.first(where: { $0.id == selectedWebhookID })
                ?? WebhookConfig(id: selectedWebhookID)
            },
            set: { updatedConfig in
                guard let index = vm.settings.webhookConfigs.firstIndex(where: { $0.id == selectedWebhookID }) else {
                    return
                }
                vm.settings.webhookConfigs[index] = updatedConfig
            }
        )
    }

    private func addWebhookRule() {
        let newRule = WebhookConfig(name: "Webhook \(vm.settings.webhookConfigs.count + 1)")
        vm.settings.webhookConfigs.append(newRule)
        selectedWebhookID = newRule.id
    }

    private func removeSelectedWebhookRule() {
        guard let selectedWebhookID else { return }
        vm.settings.webhookConfigs.removeAll { $0.id == selectedWebhookID }
        self.selectedWebhookID = vm.settings.webhookConfigs.first?.id
    }

    private func formatWebhookPayloadJSON(config: Binding<WebhookConfig>) {
        let source = config.wrappedValue.payloadTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let output = String(data: pretty, encoding: .utf8) else {
            return
        }
        config.wrappedValue.payloadTemplate = output
    }

    @ViewBuilder
    private func webhookSiteFilterRow(config: Binding<WebhookConfig>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("Site Filter:")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { config.wrappedValue.scope },
                    set: { config.wrappedValue.scope = $0 }
                )) {
                    Text("All sites").tag(WebhookScope.allSites)
                    Text("Selected sites").tag(WebhookScope.selectedSites)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260, alignment: .leading)
            }
            .frame(width: 477, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)

            if config.wrappedValue.scope == .selectedSites {
                HStack(alignment: .top, spacing: 12) {
                    Text("Sites:")
                        .frame(width: 110, alignment: .trailing)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(vm.monitors) { monitor in
                                    Toggle(monitor.nameOrHost, isOn: Binding(
                                        get: { config.wrappedValue.monitorIDs.contains(monitor.id) },
                                        set: { isOn in
                                            if isOn {
                                                if !config.wrappedValue.monitorIDs.contains(monitor.id) {
                                                    config.wrappedValue.monitorIDs.append(monitor.id)
                                                }
                                            } else {
                                                config.wrappedValue.monitorIDs.removeAll { $0 == monitor.id }
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(width: 305, height: 120)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .frame(width: 305, alignment: .leading)
                }
                .frame(width: 477, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func resizeWindow(for tab: Tab) {
        let targetSize = tab == .webhooks ? webhooksWindowSize : compactWindowSize
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
            var frame = window.frame
            let topEdge = frame.maxY
            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            frame.size = targetSize
            frame.origin = CGPoint(
                x: visibleFrame.midX - targetSize.width / 2,
                y: topEdge - targetSize.height
            )
            window.setFrame(frame, display: true, animate: true)
        }
    }
}
