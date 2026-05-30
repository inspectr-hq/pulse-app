import SwiftUI

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
                    statusColorRow("Up", color: .green)
                    statusColorRow("Slow", color: .yellow)
                    statusColorRow("Failure", color: .red)
                    statusColorRow("Offline", color: .gray)
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
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Webhooks", isOn: .constant(false))
                .disabled(true)
            Text("Webhook configuration is reserved for a later version.")
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
    private func statusColorRow(_ label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 54, alignment: .leading)
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        }
    }
}
