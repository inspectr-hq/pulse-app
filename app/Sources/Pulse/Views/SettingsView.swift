import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView {
            Form {
                Toggle("Launch app at system startup", isOn: $vm.settings.launchAtLogin)
                HStack {
                    Text("Ping Interval")
                    TextField("seconds", value: $vm.settings.pingIntervalSeconds, format: .number)
                }
                HStack {
                    Text("History retention")
                    TextField("max events", value: $vm.settings.historyRetentionMaxEvents, format: .number)
                }
            }
            .padding()
            .tabItem { Text("General") }

            Form {
                Stepper("Max Menu Items: \(vm.settings.menuMaxItems)", value: $vm.settings.menuMaxItems, in: 1...200)
                Toggle("Show method", isOn: $vm.settings.showMethodInMenu)
                Toggle("Show response time", isOn: $vm.settings.showResponseTimeInMenu)
                Toggle("Show last checked", isOn: $vm.settings.showLastCheckedInMenu)
                Toggle("Show status code", isOn: $vm.settings.showStatusCodeInMenu)
            }
            .padding()
            .tabItem { Text("Menu Bar") }
        }
        .frame(width: 520, height: 360)
        .onDisappear { vm.saveSettings() }
    }
}
