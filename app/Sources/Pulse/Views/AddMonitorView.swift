import SwiftUI

struct AddMonitorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var name = ""
    @State private var error: String?

    let onSubmit: (String, String) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Site").font(.headline)
            TextField("https://example.com", text: $url)
            TextField("Name (optional)", text: $name)
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Submit") {
                    error = onSubmit(url, name)
                    if error == nil { dismiss() }
                }
            }
        }
        .padding()
        .frame(width: 420)
    }
}
