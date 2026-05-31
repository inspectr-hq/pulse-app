import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            menuBarTab
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }

            webhooksTab
                .tabItem { Label("Webhooks", systemImage: "link") }

            supportTab
                .tabItem { Label("Support", systemImage: "info.circle") }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 600, height: 620)
        .onDisappear { vm.saveSettings() }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch app at system startup", isOn: $vm.settings.launchAtLogin)
            Toggle("Show alert badge on dock icon", isOn: $vm.settings.showAlertBadgeOnDockIcon)
            Toggle("Enable logs", isOn: $vm.settings.enableLogs)

            Divider()

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
            Stepper("Max Menu Items: \(vm.settings.menuMaxItems)", value: $vm.settings.menuMaxItems, in: 1...200)
            Picker("Colorize icon", selection: $vm.settings.menuBarIconColorMode) {
                Text("Always").tag(MenuBarIconColorMode.always)
                Text("Only failing").tag(MenuBarIconColorMode.onlyWhenFailing)
                Text("Never").tag(MenuBarIconColorMode.never)
            }
            Divider()
            Toggle("Show method", isOn: $vm.settings.showMethodInMenu)
            Toggle("Show response time", isOn: $vm.settings.showResponseTimeInMenu)
            Toggle("Show last checked", isOn: $vm.settings.showLastCheckedInMenu)
            Toggle("Show status code", isOn: $vm.settings.showStatusCodeInMenu)
            Spacer()
        }
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

    private var supportTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pulse")
                .font(.headline)
            Text("Menu bar uptime checker")
                .foregroundStyle(.secondary)
            Text("Support links and diagnostics will be added in a later version.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func alignedRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 155, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
            Spacer()
        }
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
