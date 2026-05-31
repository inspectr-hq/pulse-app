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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 13))
                        }
                        .frame(width: 98, height: 68)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
            
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 600, height: 620)
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
            
            Spacer()
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }
    
    private var webhooksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsToggleRow("Webhooks:", title: "Enable", isOn: $vm.settings.webhookEnabled)
            alignedRow("Rule:") {
                HStack(spacing: 8) {
                    Picker("", selection: selectedWebhookBinding) {
                        ForEach(vm.settings.webhookConfigs) { config in
                            Text(config.name).tag(Optional(config.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170, alignment: .leading)
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
            }

            if let index = selectedWebhookIndex {
                alignedRow("Rule Name:") {
                    TextField("Webhook", text: Binding(
                        get: { vm.settings.webhookConfigs[index].name },
                        set: { vm.settings.webhookConfigs[index].name = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                alignedRow("Send On:") {
                    Picker("", selection: Binding(
                        get: { vm.settings.webhookConfigs[index].sendOn },
                        set: { vm.settings.webhookConfigs[index].sendOn = $0 }
                    )) {
                        ForEach(WebhookSendOn.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220, alignment: .leading)
                }

                alignedRow("Site Filter:") {
                    Picker("", selection: Binding(
                        get: { vm.settings.webhookConfigs[index].scope },
                        set: { vm.settings.webhookConfigs[index].scope = $0 }
                    )) {
                        ForEach(WebhookScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220, alignment: .leading)
                }

                if vm.settings.webhookConfigs[index].scope == .selectedSites {
                    alignedRow("Sites:") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(vm.monitors) { monitor in
                                    Toggle(monitor.nameOrHost, isOn: Binding(
                                        get: { vm.settings.webhookConfigs[index].monitorIDs.contains(monitor.id) },
                                        set: { isOn in
                                            if isOn {
                                                if !vm.settings.webhookConfigs[index].monitorIDs.contains(monitor.id) {
                                                    vm.settings.webhookConfigs[index].monitorIDs.append(monitor.id)
                                                }
                                            } else {
                                                vm.settings.webhookConfigs[index].monitorIDs.removeAll { $0 == monitor.id }
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        .frame(height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                alignedRow("Webhook URL:") {
                    TextField("https://example.com/webhook", text: Binding(
                        get: { vm.settings.webhookConfigs[index].url },
                        set: { vm.settings.webhookConfigs[index].url = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                alignedRow("Method:") {
                    Picker("", selection: Binding(
                        get: { vm.settings.webhookConfigs[index].method },
                        set: { vm.settings.webhookConfigs[index].method = $0 }
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
                            get: { vm.settings.webhookConfigs[index].payloadTemplate },
                            set: { vm.settings.webhookConfigs[index].payloadTemplate = $0 }
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
                            Button("Format JSON") { formatWebhookPayloadJSON(index: index) }
                                .buttonStyle(.bordered)
                            Spacer()
                        }
                    }
                }
                alignedRow("Retries:") {
                    Stepper(value: Binding(
                        get: { vm.settings.webhookConfigs[index].maxRetries },
                        set: { vm.settings.webhookConfigs[index].maxRetries = $0 }
                    ), in: 0...8) {
                        Text("\(vm.settings.webhookConfigs[index].maxRetries)")
                    }
                    .frame(width: 120, alignment: .leading)
                }
                alignedRow("Initial Backoff:") {
                    HStack(spacing: 8) {
                        TextField("1.0", value: Binding(
                            get: { vm.settings.webhookConfigs[index].initialBackoffSeconds },
                            set: { vm.settings.webhookConfigs[index].initialBackoffSeconds = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("seconds")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                alignedRow("Rule:") {
                    Text("No webhook rules configured.")
                        .foregroundStyle(.secondary)
                }
            }

            alignedRow("Placeholders:") {
                Text("$MESSAGE, $MONITOR, $STATUS, $URL, $TRIGGER, $STATUS_CODE, $RESPONSE_MS, $TIMESTAMP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func settingsToggleRow(_ label: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .fontWeight(.none)
                .foregroundStyle(.secondary)
                .frame(width: 155, alignment: .trailing)
            Toggle(title, isOn: isOn)
                .toggleStyle(.checkbox)
                .frame(width: 260, alignment: .leading)
        }
        .frame(width: 427, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private func alignedRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 155, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
                .frame(width: 260, alignment: .leading)
        }
        .frame(width: 427, alignment: .leading)
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

    private var selectedWebhookBinding: Binding<UUID?> {
        Binding(
            get: {
                if let selectedWebhookID,
                   vm.settings.webhookConfigs.contains(where: { $0.id == selectedWebhookID }) {
                    return selectedWebhookID
                }
                return vm.settings.webhookConfigs.first?.id
            },
            set: { selectedWebhookID = $0 }
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

    private func formatWebhookPayloadJSON(index: Int) {
        let source = vm.settings.webhookConfigs[index].payloadTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let output = String(data: pretty, encoding: .utf8) else {
            return
        }
        vm.settings.webhookConfigs[index].payloadTemplate = output
    }
}
