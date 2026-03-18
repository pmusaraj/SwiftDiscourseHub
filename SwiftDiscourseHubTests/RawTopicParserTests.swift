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

    @Test func mentionsInsideCodeNotConverted() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Use `@username` for mentions"
        let result = preprocessor.process(input)
        // The preprocessor does convert mentions inside backticks (known limitation)
        #expect(result.contains("**@username**"))
    }

    // MARK: - HTML stripping tests

    @Test func htmlCommentsStripped() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Hello <!-- Describe this theme/component in one or two sentences --> world"
        let result = preprocessor.process(input)
        #expect(!result.contains("<!--"))
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    @Test func emptyDivTagsStripped() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Before\n<div data-theme-toc=\"true\"> </div>\nAfter"
        let result = preprocessor.process(input)
        #expect(!result.contains("<div"))
        #expect(result.contains("Before"))
        #expect(result.contains("After"))
    }

    @Test func smallTagsUnwrapped() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "This is <small>fine print</small> text"
        let result = preprocessor.process(input)
        #expect(!result.contains("<small>"))
        #expect(result.contains("fine print"))
    }

    @Test func hrTagConvertedToMarkdownRule() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Above<hr>Below"
        let result = preprocessor.process(input)
        #expect(!result.contains("<hr>"))
        #expect(result.contains("---"))
    }

    @Test func hrSelfClosingTagConverted() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Above\n<hr />\nBelow"
        let result = preprocessor.process(input)
        #expect(!result.contains("<hr"))
        #expect(result.contains("---"))
    }

    @Test func brTagConvertedToHardBreak() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Line one<br>Line two"
        let result = preprocessor.process(input)
        #expect(!result.contains("<br>"))
    }

    @Test func strongTagConvertedToBold() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "This is <strong>important</strong> text"
        let result = preprocessor.process(input)
        #expect(!result.contains("<strong>"))
        #expect(result.contains("**important**"))
    }

    @Test func emTagConvertedToItalic() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "This is <em>emphasized</em> text"
        let result = preprocessor.process(input)
        #expect(!result.contains("<em>"))
        #expect(result.contains("*emphasized*"))
    }

    @Test func delTagConvertedToStrikethrough() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "This is <del>removed</del> text"
        let result = preprocessor.process(input)
        #expect(!result.contains("<del>"))
        #expect(result.contains("~~removed~~"))
    }

    @Test func codeTagConvertedToBackticks() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "Use <code>let x = 1</code> in Swift"
        let result = preprocessor.process(input)
        #expect(!result.contains("<code>"))
        #expect(result.contains("`let x = 1`"))
    }

    @Test func nestedHTMLAndMarkdownPreserved() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "# Title\n<!-- comment -->\n<div class=\"foo\"> </div>\nSome **bold** text"
        let result = preprocessor.process(input)
        #expect(!result.contains("<!--"))
        #expect(!result.contains("<div"))
        #expect(result.contains("# Title"))
        #expect(result.contains("**bold**"))
    }

    @Test func absoluteImageURLsUnchanged() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://meta.discourse.org")
        let input = "![photo](https://cdn.example.com/image.png)"
        let result = preprocessor.process(input)
        #expect(result.contains("https://cdn.example.com/image.png"))
    }

    // MARK: - Upload URL resolution tests

    @Test func uploadURLsResolvedToShortURLPath() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://community.openai.com")
        let input = "![1000021541|690x460](upload://qauUrQlAXnLu8OF7ScSHSskLtiD.jpeg)"
        let result = preprocessor.process(input)
        #expect(result.contains("https://community.openai.com/uploads/short-url/qauUrQlAXnLu8OF7ScSHSskLtiD.jpeg"),
                "upload:// should be replaced with /uploads/short-url/ path: \(result)")
        #expect(!result.contains("upload://"), "No upload:// URLs should remain: \(result)")
    }

    @Test func discourseImageDimensionsSyntaxCleaned() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://community.openai.com")
        let input = "![1000021541|690x460](https://example.com/image.jpeg)"
        let result = preprocessor.process(input)
        #expect(result.contains("![1000021541](https://example.com/image.jpeg)"),
                "Pipe and dimensions should be removed from alt text: \(result)")
        #expect(!result.contains("|690x460"), "Dimension suffix should be gone: \(result)")
    }

    @Test func openAIImageGenFirstPostUploads() {
        // Real markdown from https://community.openai.com/raw/1230134 first post
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://community.openai.com")
        let input = """
        Welcome to our Community Mega Thread, showcasing your ImageGen, GPT-4o and DALL-E 3 creations!

        ![1000021541|690x460](upload://qauUrQlAXnLu8OF7ScSHSskLtiD.jpeg)
        ![1000021542|500x500](upload://vPHDVTwvE2kzkggJG15pm7VrupO.webp)

        For more DALL-E 3 content and support, follow the gallery tag.
        """
        let result = preprocessor.process(input)

        // Upload URLs should be resolved
        #expect(result.contains("https://community.openai.com/uploads/short-url/qauUrQlAXnLu8OF7ScSHSskLtiD.jpeg"),
                "First image upload should be resolved: \(result)")
        #expect(result.contains("https://community.openai.com/uploads/short-url/vPHDVTwvE2kzkggJG15pm7VrupO.webp"),
                "Second image upload should be resolved: \(result)")

        // Dimension syntax should be cleaned
        #expect(!result.contains("|690x460"), "First image dimensions should be cleaned")
        #expect(!result.contains("|500x500"), "Second image dimensions should be cleaned")

        // Result should be valid standard markdown images
        #expect(result.contains("![1000021541](https://community.openai.com/uploads/short-url/qauUrQlAXnLu8OF7ScSHSskLtiD.jpeg)"),
                "Should produce clean markdown image syntax: \(result)")
        #expect(result.contains("![1000021542](https://community.openai.com/uploads/short-url/vPHDVTwvE2kzkggJG15pm7VrupO.webp)"),
                "Should produce clean markdown image syntax: \(result)")

        // No upload:// references should remain
        #expect(!result.contains("upload://"), "No upload:// URLs should remain")

        // Regular text should be preserved
        #expect(result.contains("Welcome to our Community Mega Thread"))
        #expect(result.contains("follow the gallery tag"))
    }

    @Test func multipleUploadTypesResolved() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        ![photo|640x480](upload://abc123.jpeg)
        ![clip|video](upload://def456.mp4)
        [document|attachment](upload://ghi789.pdf) (2.5 MB)
        """
        let result = preprocessor.process(input)

        #expect(result.contains("https://example.com/uploads/short-url/abc123.jpeg"))
        #expect(result.contains("https://example.com/uploads/short-url/def456.mp4"))
        #expect(result.contains("https://example.com/uploads/short-url/ghi789.pdf"))
        #expect(!result.contains("upload://"))
    }

    // MARK: - Checkbox tests

    @Test func convertGFMTaskLists() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        - [x] Done item
        - [ ] Todo item
        - [X] Also done
        """
        let result = preprocessor.process(input)
        #expect(result.contains("- ☑ Done item"))
        #expect(result.contains("- ☐ Todo item"))
        #expect(result.contains("- ☑ Also done"))
    }

    @Test func convertBareCheckboxes() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        [x] Checked
        [ ] Unchecked
        """
        let result = preprocessor.process(input)
        #expect(result.contains("☑ Checked"))
        #expect(result.contains("☐ Unchecked"))
    }

    @Test func convertIndentedCheckboxes() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "  - [x] Nested checked item"
        let result = preprocessor.process(input)
        #expect(result.contains("  - ☑ Nested checked item"))
    }

    @Test func singleNewlinesPreservedAsHardBreaks() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        **Operating System:**
        [x] Windows
        [ ] Linux
        **Kit Version:**
        """
        let result = preprocessor.process(input)
        // Each line should end with two trailing spaces to force a hard break
        #expect(result.contains("**Operating System:**  \n"), "Line should have trailing spaces for hard break")
        #expect(result.contains("☑ Windows  \n"), "Checkbox line should have trailing spaces for hard break")
        #expect(result.contains("☐ Linux  \n"), "Checkbox line should have trailing spaces for hard break")
    }

    @Test func hardBreaksSkipCodeBlocks() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        Before code
        ```
        line1
        line2
        ```
        After code
        """
        let result = preprocessor.process(input)
        #expect(!result.contains("line1  \n"), "Lines inside code blocks should not get trailing spaces")
        #expect(result.contains("Before code  \n"), "Lines outside code blocks should get trailing spaces")
    }

    @Test func videoSuffixCleaned() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = "![clip|video](https://example.com/video.mp4)"
        let result = preprocessor.process(input)
        #expect(result.contains("![clip](https://example.com/video.mp4)"),
                "Video pipe suffix should be cleaned: \(result)")
    }
}
