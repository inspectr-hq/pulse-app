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
            settingsToggleRow("Logs:", title: "Enable logs", isOn: $vm.settings.enableLogs)
            
            Divider()
                .frame(width: 427)
                .frame(maxWidth: .infinity, alignment: .center)
            
            alignedRow("Ping Interval:") {
                HStack(spacing: 8) {
                    TextField("900", value: $vm.settings.pingIntervalSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }
            
            alignedRow("Pause Ping when:") {
                Picker("", selection: $vm.settings.pausePingWhen) {
                    ForEach(PausePingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140, alignment: .leading)
            }
            
            alignedRow("Stagger Requests:") {
                HStack(spacing: 8) {
                    TextField("0", value: $vm.settings.staggerRequestsSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("seconds between")
                        .foregroundStyle(.secondary)
                }
            }
            
            alignedRow("Failures to Alert:") {
                Stepper(value: $vm.settings.failuresToAlert, in: 1...20) {
                    Text("\(vm.settings.failuresToAlert) consecutive")
                }
                .frame(width: 220, alignment: .leading)
            }
            
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }
    
    private var webhooksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Webhooks", isOn: $vm.settings.webhookEnabled)
            alignedRow("Send On:") {
                Picker("", selection: $vm.settings.webhookSendOn) {
                    ForEach(WebhookSendOn.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 220, alignment: .leading)
            }
            alignedRow("Webhook URL:") {
                TextField("https://example.com/webhook", text: $vm.settings.webhookURL)
                    .textFieldStyle(.roundedBorder)
            }
            alignedRow("Method:") {
                Picker("", selection: $vm.settings.webhookMethod) {
                    Text("POST").tag(HTTPMethod.post)
                    Text("GET").tag(HTTPMethod.get)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120, alignment: .leading)
            }
            alignedRow("Payload:") {
                TextEditor(text: $vm.settings.webhookPayloadTemplate)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            }
            alignedRow("Retries:") {
                Stepper(value: $vm.settings.webhookMaxRetries, in: 0...8) {
                    Text("\(vm.settings.webhookMaxRetries)")
                }
                .frame(width: 120, alignment: .leading)
            }
            alignedRow("Initial Backoff:") {
                HStack(spacing: 8) {
                    TextField("1.0", value: $vm.settings.webhookInitialBackoffSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Placeholders: $MESSAGE, $MONITOR, $STATUS, $URL, $TRIGGER, $STATUS_CODE, $RESPONSE_MS, $TIMESTAMP")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
