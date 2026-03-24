import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ComposerView: View {
    let site: DiscourseSite
    let topicId: Int
    @Binding var composerText: String
    var onPostCreated: (() -> Void)?
    var onCancel: (() -> Void)?

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var editorHeight: CGFloat?
    @State private var manualHeightOffset: CGFloat = 0
    @State private var uploads: [UploadResponse] = []
    @State private var uploadThumbnails: [Int: Image] = [:]
    @State private var isUploading = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var mentionSuggestions: [DiscourseUser] = []
    @State private var mentionSelectedIndex: Int = 0
    @State private var mentionSearchTask: Task<Void, Never>?
    @FocusState private var isEditorFocused: Bool
    @Environment(\.apiClient) private var apiClient
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var effectiveHeight: CGFloat {
        let lineCount = max(1, composerText.components(separatedBy: .newlines).count)
        let clampedLines = min(lineCount, Theme.Composer.maxAutoLines)
        #if os(macOS)
        let vPad: CGFloat = 2
        #else
        let vPad: CGFloat = 8
        #endif
        let height = CGFloat(clampedLines) * Theme.Composer.lineHeight + vPad
        return max(Theme.Composer.lineHeight + vPad, height + manualHeightOffset)
    }

    private var composerBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(.windowBackgroundColor)
        #endif
    }

    private var canSubmit: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle (non-compact only)
            if !isCompact {
                HStack {
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: Theme.Composer.resizeHandleHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            manualHeightOffset = max(-(effectiveHeight - Theme.Composer.lineHeight - 8), manualHeightOffset - value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height > 60 {
                                onCancel?()
                            }
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
            }

            // Thumbnail strip
            if !uploads.isEmpty || isUploading {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(uploads, id: \.id) { upload in
                            uploadThumbnailView(upload)
                        }
                        if isUploading {
                            VStack(spacing: 4) {
                                ProgressView()
                                    .frame(width: Theme.Composer.thumbnailSize, height: Theme.Composer.thumbnailSize)
                                Text("Uploading...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.never)
            }

            if let error = submitError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Main input row: + button | text editor | reply button
            HStack(alignment: .bottom, spacing: Theme.Composer.rowSpacing) {
                // Attach menu (+ button)
                Menu {
                    #if os(iOS)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .screenshots])) {
                        Label("Photo Library", systemImage: "photo")
                    }
                    #endif
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.tint)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .frame(height: Theme.Composer.plusButtonSize)
                .disabled(isUploading)

                // Text input
                TextEditor(text: $composerText)
                    .focused($isEditorFocused)
                    .frame(height: effectiveHeight)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    #if os(macOS)
                    .contentMargins(.all, 0)
                    #endif
                    .padding(.horizontal, Theme.Composer.inputPaddingH)
                    .padding(.vertical, Theme.Composer.inputPaddingV)
                    #if os(iOS)
                    .background(Color(.secondarySystemBackground))
                    #else
                    .background(Color(.controlBackgroundColor))
                    #endif
                    .clipShape(.rect(cornerRadius: Theme.Composer.inputCornerRadius))
                    .onAppear { isEditorFocused = true }
                    .overlay(alignment: .topLeading) {
                        if !mentionSuggestions.isEmpty {
                            mentionSuggestionsView
                                .offset(y: -CGFloat(min(mentionSuggestions.count, 6) * 36) - 8)
                        }
                    }
                    .onKeyPress(.upArrow) {
                        guard !mentionSuggestions.isEmpty else { return .ignored }
                        mentionSelectedIndex = max(0, mentionSelectedIndex - 1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        guard !mentionSuggestions.isEmpty else { return .ignored }
                        mentionSelectedIndex = min(min(mentionSuggestions.count, 6) - 1, mentionSelectedIndex + 1)
                        return .handled
                    }
                    .onKeyPress(.return) {
                        guard !mentionSuggestions.isEmpty else { return .ignored }
                        let index = mentionSelectedIndex
                        let suggestions = Array(mentionSuggestions.prefix(6))
                        guard index < suggestions.count else { return .ignored }
                        insertMention(username: suggestions[index].username ?? "")
                        return .handled
                    }
                    .onKeyPress(.tab) {
                        guard !mentionSuggestions.isEmpty else { return .ignored }
                        let index = mentionSelectedIndex
                        let suggestions = Array(mentionSuggestions.prefix(6))
                        guard index < suggestions.count else { return .ignored }
                        insertMention(username: suggestions[index].username ?? "")
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        guard !mentionSuggestions.isEmpty else { return .ignored }
                        mentionSuggestions = []
                        return .handled
                    }
                    .onChange(of: composerText) { _, _ in
                        updateMentionSearch()
                    }

                // Reply button
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else if isCompact {
                        Image(systemName: "paperplane.fill")
                    } else {
                        Label("Reply", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: Theme.Composer.plusButtonSize)
                .disabled(!canSubmit)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, Theme.Composer.containerPaddingH)
            .padding(.vertical, Theme.Composer.containerPaddingV)
        }
        .background(composerBackground)
        .padding(.bottom, 0)
        .background(composerBackground)
        .clipShape(.rect(cornerRadius: isCompact ? Theme.Composer.containerCornerRadiusCompact : Theme.Composer.containerCornerRadiusRegular))
        .shadow(color: .black.opacity(Theme.Composer.shadowOpacity), radius: Theme.Composer.shadowRadius, y: -2)
        .padding(.horizontal, isCompact ? 0 : 8)
        .padding(.bottom, isCompact ? 0 : 4)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhotoSelection(newItem) }
            selectedPhotoItem = nil
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image, .pdf, .data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await handleFileSelection(url) }
                }
            case .failure(let error):
                submitError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func uploadThumbnailView(_ upload: UploadResponse) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if upload.width != nil, let thumbnail = uploadThumbnails[upload.id] {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Theme.Composer.thumbnailSize, height: Theme.Composer.thumbnailSize)
                        .clipShape(.rect(cornerRadius: Theme.Composer.thumbnailCornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Composer.thumbnailCornerRadius)
                        .fill(.quaternary)
                        .frame(width: Theme.Composer.thumbnailSize, height: Theme.Composer.thumbnailSize)
                        .overlay {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                        }
                }
                Button {
                    uploads.removeAll { $0.id == upload.id }
                    uploadThumbnails.removeValue(forKey: upload.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
            Text(upload.originalFilename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: Theme.Composer.thumbnailSize)
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        isUploading = true
        submitError = nil
        defer { isUploading = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            submitError = "Failed to load photo"
            return
        }

        let mimeType: String
        let fileName: String
        if let contentType = item.supportedContentTypes.first,
           let ext = contentType.preferredFilenameExtension {
            mimeType = contentType.preferredMIMEType ?? "image/jpeg"
            fileName = "photo.\(ext)"
        } else {
            mimeType = "image/jpeg"
            fileName = "photo.jpg"
        }

        await performUpload(data: data, fileName: fileName, mimeType: mimeType, thumbnailData: data)
    }

    private func handleFileSelection(_ url: URL) async {
        isUploading = true
        submitError = nil
        defer { isUploading = false }

        guard url.startAccessingSecurityScopedResource() else {
            submitError = "Cannot access selected file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            submitError = "Failed to read file"
            return
        }

        let fileName = url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
        let mimeType = contentType.preferredMIMEType ?? "application/octet-stream"
        let isImage = contentType.conforms(to: .image)

        await performUpload(data: data, fileName: fileName, mimeType: mimeType, thumbnailData: isImage ? data : nil)
    }

    private func performUpload(data: Data, fileName: String, mimeType: String, thumbnailData: Data?) async {
        do {
            let response = try await apiClient.uploadFile(baseURL: site.baseURL, data: data, fileName: fileName, mimeType: mimeType)
            uploads.append(response)

            if let thumbnailData, response.width != nil {
                #if os(macOS)
                if let nsImage = NSImage(data: thumbnailData) {
                    uploadThumbnails[response.id] = Image(nsImage: nsImage)
                }
                #else
                if let uiImage = UIImage(data: thumbnailData) {
                    uploadThumbnails[response.id] = Image(uiImage: uiImage)
                }
                #endif
            }
        } catch {
            submitError = error.localizedDescription
        }
    }

    // MARK: - Mention Autocomplete

    @ViewBuilder
    private var mentionSuggestionsView: some View {
        let visibleSuggestions = Array(mentionSuggestions.prefix(6))
        VStack(spacing: 0) {
            ForEach(Array(visibleSuggestions.enumerated()), id: \.element.id) { index, user in
                Button {
                    insertMention(username: user.username ?? "")
                } label: {
                    HStack(spacing: 8) {
                        if let avatarTemplate = user.avatarTemplate {
                            let avatarURL = avatarTemplate.hasPrefix("http")
                                ? URL(string: avatarTemplate.replacing("{size}", with: "48"))
                                : URL(string: site.baseURL + avatarTemplate.replacing("{size}", with: "48"))
                            CachedAsyncImage(url: avatarURL) { image in
                                image.resizable()
                            } placeholder: {
                                Circle().fill(.quaternary)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        }
                        Text(user.username ?? "")
                            .fontWeight(.medium)
                        if let name = user.name, !name.isEmpty {
                            Text(name)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(index == mentionSelectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < visibleSuggestions.count - 1 {
                    Divider()
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        .padding(.horizontal, 8)
    }

    private func extractMentionFragment() -> String? {
        let text = composerText
        guard !text.isEmpty else { return nil }

        var i = text.endIndex
        while i > text.startIndex {
            let prev = text.index(before: i)
            let ch = text[prev]
            if ch == "@" {
                if prev == text.startIndex || text[text.index(before: prev)].isWhitespace || text[text.index(before: prev)].isNewline {
                    let fragment = String(text[i...].prefix(while: { !$0.isWhitespace && !$0.isNewline }))
                    let endOfFragment = text.index(i, offsetBy: fragment.count)
                    if endOfFragment == text.endIndex {
                        return fragment.isEmpty ? nil : fragment
                    }
                }
                return nil
            }
            if ch.isWhitespace || ch.isNewline {
                return nil
            }
            i = prev
        }
        return nil
    }

    private func updateMentionSearch() {
        mentionSearchTask?.cancel()

        guard let fragment = extractMentionFragment(), fragment.count >= 1 else {
            if !mentionSuggestions.isEmpty {
                mentionSuggestions = []
                mentionSelectedIndex = 0
            }
            return
        }

        mentionSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let users = try await apiClient.searchUsers(baseURL: site.baseURL, term: fragment, topicId: topicId)
                guard !Task.isCancelled else { return }
                mentionSuggestions = users
                mentionSelectedIndex = 0
            } catch {
                if !Task.isCancelled {
                    mentionSuggestions = []
                }
            }
        }
    }

    private func insertMention(username: String) {
        guard !username.isEmpty else { return }
        if let fragment = extractMentionFragment() {
            let searchSuffix = "@" + fragment
            if composerText.hasSuffix(searchSuffix) {
                composerText = String(composerText.dropLast(searchSuffix.count)) + "@\(username) "
            }
        }
        mentionSuggestions = []
        isEditorFocused = true
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        submitError = nil

        var raw = composerText
        if !uploads.isEmpty {
            raw += "\n"
            for upload in uploads {
                if let w = upload.width, let h = upload.height {
                    raw += "\n![\(upload.originalFilename)|\(w)x\(h)](\(upload.shortUrl))"
                } else {
                    raw += "\n[\(upload.originalFilename)](\(upload.shortUrl))"
                }
            }
        }

        do {
            _ = try await apiClient.createPost(baseURL: site.baseURL, topicId: topicId, raw: raw)
            composerText = ""
            uploads = []
            uploadThumbnails = [:]
            onPostCreated?()
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty") {
    ComposerPreviewWrapper(text: "")
}

#Preview("Single line") {
    ComposerPreviewWrapper(text: "I agree with this proposal!")
}

#Preview("Multi-line") {
    ComposerPreviewWrapper(text: "Here are my thoughts:\n\n1. The API looks good\n2. We should add tests")
}

#Preview("With error") {
    ComposerPreviewWrapper(text: "Test reply", error: "Network connection lost")
}

private struct ComposerPreviewWrapper: View {
    @State var text: String
    var error: String?

    var body: some View {
        VStack {
            Spacer()
            ComposerView(
                site: DiscourseSite(baseURL: "https://meta.discourse.org", title: "Discourse Meta"),
                topicId: 1,
                composerText: $text
            )
        }
        .frame(maxWidth: .infinity)
        #if os(iOS)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
    }
}
#endif
