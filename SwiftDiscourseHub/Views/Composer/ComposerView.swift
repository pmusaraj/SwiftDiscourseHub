import SwiftUI

struct ComposerView: View {
    let site: DiscourseSite
    let topicId: Int
    @Binding var composerText: String
    var onPostCreated: (() -> Void)?

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var selection: TextSelection?
    @State private var editorHeight: CGFloat = 52
    @FocusState private var isEditorFocused: Bool
    @Environment(\.apiClient) private var apiClient

    private var canSubmit: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Resize handle at top
            HStack {
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        editorHeight = max(32, editorHeight - value.translation.height)
                    }
            )
            #if os(macOS)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif

            TextEditor(text: $composerText, selection: $selection)
                .focused($isEditorFocused)
                .frame(height: editorHeight)
                .font(.body)
                .padding(.horizontal, 8)
                .scrollContentBackground(.hidden)
                .onAppear { isEditorFocused = true }

            if let error = submitError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal, 12)
            }

            HStack {
                Spacer()
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Reply", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canSubmit)
                .keyboardShortcut(.return, modifiers: .command)
                .padding(8)
            }
        }
        .background(.bar)
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        submitError = nil

        do {
            _ = try await apiClient.createPost(baseURL: site.baseURL, topicId: topicId, raw: composerText)
            composerText = ""
            onPostCreated?()
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - MarkdownFormatter

enum MarkdownFormatter {
    enum Format {
        case bold, italic, link, quote
    }

    static func apply(_ format: Format, to text: String) -> String {
        switch format {
        case .bold:
            return toggleWrap(text, prefix: "**", suffix: "**", placeholder: "bold text")
        case .italic:
            return toggleWrap(text, prefix: "*", suffix: "*", placeholder: "italic text")
        case .link:
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text + "[link text](url)"
            }
            return text + "[link text](url)"
        case .quote:
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text + "> "
            }
            let lines = text.components(separatedBy: "\n")
            return lines.map { line in
                if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
                return "> " + line
            }.joined(separator: "\n")
        }
    }

    static func bold(_ text: String) -> String { apply(.bold, to: text) }
    static func italic(_ text: String) -> String { apply(.italic, to: text) }
    static func link(_ text: String) -> String { apply(.link, to: text) }
    static func quote(_ text: String) -> String { apply(.quote, to: text) }

    static func quoteReply(text: String, username: String, topicId: Int, postNumber: Int) -> String {
        let quoted = text.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
        return "[quote=\"\(username), post:\(postNumber), topic:\(topicId)\"]\n\(quoted)\n[/quote]\n\n"
    }

    private static func toggleWrap(_ text: String, prefix: String, suffix: String, placeholder: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return text + "\(prefix)\(placeholder)\(suffix)"
        }
        if trimmed.hasPrefix(prefix) && trimmed.hasSuffix(suffix) && trimmed.count > prefix.count + suffix.count {
            let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -suffix.count)
            return String(trimmed[start..<end])
        }
        return "\(prefix)\(trimmed)\(suffix)"
    }
}
