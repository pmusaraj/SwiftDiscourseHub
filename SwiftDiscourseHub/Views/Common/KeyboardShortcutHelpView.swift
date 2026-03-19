import SwiftUI

struct KeyboardShortcutHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Navigation") {
                    shortcutRow("Next topic", keys: "\u{2318}\u{2193}")
                    shortcutRow("Previous topic", keys: "\u{2318}\u{2191}")
                    shortcutRow("Next site", keys: "\u{2325}\u{2193}")
                    shortcutRow("Previous site", keys: "\u{2325}\u{2191}")
                    shortcutRow("Scroll topic down", keys: "Space")
                    shortcutRow("Scroll topic up", keys: "\u{21E7} Space")
                }
                Section("Filters") {
                    shortcutRow("Hot topics", keys: "g then h")
                    shortcutRow("New topics", keys: "g then n")
                    shortcutRow("Latest topics", keys: "g then l")
                }
                Section("Actions") {
                    shortcutRow("Reply to topic", keys: "r")
                    shortcutRow("Show this help", keys: "?")
                }
            }
            .navigationTitle("Keyboard Shortcuts")
            #if os(macOS)
            .frame(minWidth: 340, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
