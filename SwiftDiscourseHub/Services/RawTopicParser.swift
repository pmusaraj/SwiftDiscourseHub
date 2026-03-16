import Foundation

struct RawPost {
    let postNumber: Int
    let username: String
    let markdown: String
}

struct RawTopicParser {
    static func parse(_ rawText: String) -> [RawPost] {
        let separator = "\n\n-------------------------\n"
        let chunks = rawText.components(separatedBy: separator)

        var posts: [RawPost] = []
        var pendingMarkdown: String?

        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if let (postNumber, username, markdown) = parseChunk(trimmed) {
                // If there was pending markdown without a header, it belongs to post #1
                if let pending = pendingMarkdown {
                    posts.append(RawPost(postNumber: 1, username: "", markdown: pending))
                    pendingMarkdown = nil
                }
                posts.append(RawPost(postNumber: postNumber, username: username, markdown: markdown))
            } else if posts.isEmpty {
                // First chunk with no header — this is post #1 (header is omitted for single-post or first post)
                pendingMarkdown = trimmed
            } else {
                // Chunk without a valid header — re-join with previous post (separator appeared in content)
                if let last = posts.last {
                    posts.removeLast()
                    let rejoined = last.markdown + "\n\n-------------------------\n\n" + trimmed
                    posts.append(RawPost(postNumber: last.postNumber, username: last.username, markdown: rejoined))
                }
            }
        }

        if let pending = pendingMarkdown {
            posts.append(RawPost(postNumber: 1, username: "", markdown: pending))
        }

        return posts
    }

    private static func parseChunk(_ chunk: String) -> (postNumber: Int, username: String, markdown: String)? {
        // Header format: "username | 2024-01-15 12:00:00 UTC | #3"
        guard let newlineIndex = chunk.firstIndex(of: "\n") else {
            // Single line — check if it's a header-only chunk
            return parseHeader(chunk).map { ($0.postNumber, $0.username, "") }
        }

        let headerLine = String(chunk[chunk.startIndex..<newlineIndex])
        guard let header = parseHeader(headerLine) else { return nil }

        let markdown = String(chunk[chunk.index(after: newlineIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (header.postNumber, header.username, markdown)
    }

    private static func parseHeader(_ line: String) -> (username: String, postNumber: Int)? {
        let parts = line.components(separatedBy: " | ")
        guard parts.count >= 3 else { return nil }

        let username = parts[0].trimmingCharacters(in: .whitespaces)
        let postPart = parts.last!.trimmingCharacters(in: .whitespaces)

        guard postPart.hasPrefix("#"),
              let postNumber = Int(postPart.dropFirst()) else { return nil }

        return (username, postNumber)
    }
}
