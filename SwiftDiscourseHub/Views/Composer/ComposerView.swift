import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ComposerView: View {
    let site: DiscourseSite
    let topicId: Int
    @Binding var composerText: String
    var onPostCreated: (() -> Void)?

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var selection: TextSelection?
    @State private var editorHeight: CGFloat = 52
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
                                    .frame(width: 60, height: 60)
                                Text("Uploading...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
            }

            if let error = submitError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal, 12)
            }

            HStack {
                Menu {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .any(of: [.images, .screenshots])) {
                        Label("Photo Library", systemImage: "photo")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose File", systemImage: "doc")
                    }
                } label: {
                    Label("Attach", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .font(.body)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.leading, 8)
                .disabled(isUploading)

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
                        .frame(width: 60, height: 60)
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(width: 60, height: 60)
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
                .frame(width: 60)
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
        // Look for @fragment at the end of the text (simple heuristic when selection isn't easily usable)
        let text = composerText
        guard !text.isEmpty else { return nil }

        // Find the last @ that starts a mention
        var i = text.endIndex
        while i > text.startIndex {
            let prev = text.index(before: i)
            let ch = text[prev]
            if ch == "@" {
                // Check that @ is at start of text or preceded by whitespace/newline
                if prev == text.startIndex || text[text.index(before: prev)].isWhitespace || text[text.index(before: prev)].isNewline {
                    let fragment = String(text[i...].prefix(while: { !$0.isWhitespace && !$0.isNewline }))
                    // Only trigger if the fragment runs to the end (cursor is at end of mention)
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
            mentionSuggestions = []
            mentionSelectedIndex = 0
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
        // Find the @fragment at the end and replace it
        if let fragment = extractMentionFragment() {
            let searchSuffix = "@" + fragment
            if composerText.hasSuffix(searchSuffix) {
                composerText = String(composerText.dropLast(searchSuffix.count)) + "@\(username) "
                selection = .init(insertionPoint: composerText.endIndex)
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
