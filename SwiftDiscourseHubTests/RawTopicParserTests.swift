import Testing
import Foundation

@testable import SwiftDiscourseHub

@MainActor struct RawTopicParserTests {

    // MARK: - RawTopicParser tests

    @Test func parseSinglePost() {
        let raw = """
        This is the first post content.

        It has multiple paragraphs.

        -------------------------
        """
        let posts = RawTopicParser.parse(raw)
        #expect(posts.count == 1)
        #expect(posts[0].postNumber == 1)
        #expect(posts[0].markdown.contains("first post content"))
    }

    @Test func parseMultiplePosts() {
        let raw = """
        First post content here.

        -------------------------

        user2 | 2024-01-15 12:00:00 UTC | #2

        Second post content.

        -------------------------

        user3 | 2024-02-01 08:30:00 UTC | #3

        Third post content.

        -------------------------
        """
        let posts = RawTopicParser.parse(raw)
        #expect(posts.count == 3)
        #expect(posts[0].postNumber == 1)
        #expect(posts[0].markdown.contains("First post"))
        #expect(posts[1].postNumber == 2)
        #expect(posts[1].username == "user2")
        #expect(posts[1].markdown.contains("Second post"))
        #expect(posts[2].postNumber == 3)
        #expect(posts[2].username == "user3")
    }

    @Test func parsePostNumberGaps() {
        let raw = """
        First post.

        -------------------------

        alice | 2024-01-15 12:00:00 UTC | #2

        Second post.

        -------------------------

        bob | 2024-01-16 08:00:00 UTC | #5

        Fifth post (3 and 4 were deleted).

        -------------------------
        """
        let posts = RawTopicParser.parse(raw)
        #expect(posts.count == 3)
        #expect(posts[0].postNumber == 1)
        #expect(posts[1].postNumber == 2)
        #expect(posts[2].postNumber == 5)
    }

    @Test func parseSeparatorInContent() {
        // If a post contains 25 dashes, the next chunk won't have a valid header
        // so it should be re-joined with the previous post
        let raw = """
        First post with a horizontal rule:

        -------------------------

        This is still part of post 1.

        -------------------------

        user2 | 2024-01-15 12:00:00 UTC | #2

        Second post.

        -------------------------
        """
        let posts = RawTopicParser.parse(raw)
        #expect(posts.count == 2)
        #expect(posts[0].postNumber == 1)
        #expect(posts[0].markdown.contains("still part of post 1"))
        #expect(posts[1].postNumber == 2)
    }

    // MARK: - Preprocessor tests

    @Test func resolveRelativeImageURLs() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://meta.discourse.org")
        let input = "![screenshot](/uploads/default/original/1X/abc.png)"
        let result = preprocessor.process(input)
        #expect(result.contains("https://meta.discourse.org/uploads/default/original/1X/abc.png"))
    }

    @Test func convertQuotes() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        [quote="alice, post:3, topic:123"]
        This is a quote.
        [/quote]
        """
        let result = preprocessor.process(input)
        #expect(result.contains("**alice:**"))
        #expect(result.contains("> This is a quote."))
    }

    @Test func convertDetails() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        [details="Click to expand"]
        Hidden content here.
        [/details]
        """
        let result = preprocessor.process(input)
        #expect(result.contains("**Click to expand**"))
        #expect(result.contains("Hidden content here."))
    }

    @Test func convertMentions() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Hello @alice and @bob-smith!"
        let result = preprocessor.process(input)
        #expect(result.contains("**@alice**"))
        #expect(result.contains("**@bob-smith**"))
    }

    @Test func extractUploadShortURLs() {
        let markdown = """
        ![photo|640x480](upload://qUm0DGR49PAZshIi7HxMd3cAlzn.jpeg)
        Some text here.
        ![video|video](upload://abc123DEF456.mp4)
        """
        let urls = DiscourseMarkdownPreprocessor.extractUploadShortURLs(from: markdown)
        #expect(urls.count == 2)
        #expect(urls.contains("upload://qUm0DGR49PAZshIi7HxMd3cAlzn.jpeg"))
        #expect(urls.contains("upload://abc123DEF456.mp4"))
    }

    @Test func replaceUploadURLs() {
        let markdown = "![photo|640x480](upload://abc123.jpeg)"
        let mapping = ["upload://abc123.jpeg": "https://cdn.example.com/uploads/original/1X/abc123.jpeg"]
        let result = DiscourseMarkdownPreprocessor.replaceUploadURLs(in: markdown, mapping: mapping)
        #expect(result.contains("https://cdn.example.com/uploads/original/1X/abc123.jpeg"))
        #expect(!result.contains("upload://"))
    }

    @Test func mentionsInsideCodeNotConverted() {
        // Mentions inside inline code should ideally not be converted,
        // but our simple regex will convert them. This test documents the behavior.
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Use `@username` for mentions"
        let result = preprocessor.process(input)
        // The preprocessor does convert mentions inside backticks (known limitation)
        #expect(result.contains("**@username**"))
    }

    @Test func absoluteImageURLsUnchanged() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://meta.discourse.org")
        let input = "![photo](https://cdn.example.com/image.png)"
        let result = preprocessor.process(input)
        #expect(result.contains("https://cdn.example.com/image.png"))
    }
}
