import SwiftUI

struct EditMonitorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SiteMonitor
    @State private var rawURL: String
    let onSubmit: (SiteMonitor) -> Void

    init(monitor: SiteMonitor, onSubmit: @escaping (SiteMonitor) -> Void) {
        _draft = State(initialValue: monitor)
        _rawURL = State(initialValue: monitor.url.absoluteString)
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit Site").font(.headline)
            HStack { Text("URL:"); TextField("URL", text: $rawURL) }
            HStack { Text("Name:"); TextField("Name", text: $draft.displayName) }
            Divider()
            HStack { Text("Method:"); Picker("", selection: $draft.method) { ForEach(HTTPMethod.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden() }
            HStack { Text("Threshold:"); TextField("ms", value: $draft.thresholdMs, format: .number) }
            HStack { Text("Keyword:"); TextField("Keyword", text: $draft.keyword) }
            Toggle("Active", isOn: $draft.isEnabled)
            Toggle("Allow insecure SSL", isOn: $draft.allowInsecureSSL)
            Text("Body")
            TextEditor(text: $draft.body).frame(height: 70)
            Divider()
            HStack {
                Text("Headers")
                Button("Add") { draft.headers.append(.init(name: "", value: "")) }
            }
            ForEach($draft.headers) { $header in
                HStack {
                    TextField("Name", text: $header.name)
                    TextField("Value", text: $header.value)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Submit") {
                    if let url = URLInput.normalize(rawURL) {
                        draft.url = url
                        onSubmit(draft)
                        dismiss()
                    }
                }
            }
        }
        .padding()
        .frame(width: 520)
    }
}
