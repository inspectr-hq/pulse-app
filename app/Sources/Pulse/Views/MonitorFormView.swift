import SwiftUI

struct MonitorFormView: View {
    enum Mode {
        case add
        case edit

        var title: String {
            switch self {
            case .add: return "Add Site"
            case .edit: return "Edit Site"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let initialMonitor: SiteMonitor
    let onSubmit: (SiteMonitor, String) -> String?

    @State private var draft: SiteMonitor
    @State private var rawURL: String
    @State private var errorMessage: String?

    init(mode: Mode, monitor: SiteMonitor, onSubmit: @escaping (SiteMonitor, String) -> String?) {
        self.mode = mode
        self.initialMonitor = monitor
        self.onSubmit = onSubmit
        _draft = State(initialValue: monitor)
        _rawURL = State(initialValue: monitor.url.absoluteString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.title)
                .font(.title3)
                .fontWeight(.semibold)

            Group {
                labeledRow("URL:") {
                    TextField("https://example.com", text: $rawURL)
                        .textFieldStyle(.roundedBorder)
                }
                labeledRow("Name:") {
                    TextField("Display name", text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            sectionHeader("Request")
            labeledRow("Method:") {
                Picker("Method", selection: $draft.method) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            labeledRow("Body:") {
                TextField("Body content payload", text: $draft.body)
                    .textFieldStyle(.roundedBorder)
            }
            labeledRow("Headers:") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(draft.headers.enumerated()), id: \.element.id) { index, header in
                        HStack(spacing: 8) {
                            TextField("Name", text: bindingForHeader(at: index, keyPath: \.name))
                                .textFieldStyle(.roundedBorder)
                            TextField("Value", text: bindingForHeader(at: index, keyPath: \.value))
                                .textFieldStyle(.roundedBorder)
                            Button {
                                draft.headers.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        draft.headers.append(HeaderEntry(name: "", value: ""))
                    } label: {
                        Label("Add Header", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            labeledRow("") {
                Toggle("Allow insecure SSL", isOn: $draft.allowInsecureSSL)
                    .toggleStyle(.checkbox)
            }

            Divider()

            sectionHeader("Response")
            labeledRow("Threshold:") {
                HStack(spacing: 8) {
                    TextField("2000", value: $draft.thresholdMs, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
            }
            labeledRow("Keyword:") {
                TextField("Monitor keyword in response", text: $draft.keyword)
                    .textFieldStyle(.roundedBorder)
            }
            labeledRow("") {
                Toggle("Active", isOn: $draft.isEnabled)
                    .toggleStyle(.checkbox)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Submit") {
                    errorMessage = onSubmit(draft, rawURL)
                    if errorMessage == nil {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
    }

    private func bindingForHeader(at index: Int, keyPath: WritableKeyPath<HeaderEntry, String>) -> Binding<String> {
        Binding(
            get: {
                guard draft.headers.indices.contains(index) else { return "" }
                return draft.headers[index][keyPath: keyPath]
            },
            set: { newValue in
                guard draft.headers.indices.contains(index) else { return }
                draft.headers[index][keyPath: keyPath] = newValue
            }
        )
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Divider()
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 88, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
