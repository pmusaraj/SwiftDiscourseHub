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

    @Test func quotesPreservedForSegmentExtraction() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        [quote="alice, post:3, topic:123"]
        This is a quote.
        [/quote]
        """
        let result = preprocessor.process(input)
        // Quotes are no longer converted to blockquotes — they're left intact
        // for the view layer to render as enriched quote blocks
        #expect(result.contains("[quote=\"alice, post:3, topic:123\"]"))
        #expect(result.contains("[/quote]"))

        // Verify segment extraction works
        let segments = DiscourseMarkdownPreprocessor.extractSegments(from: result)
        #expect(segments.count == 1)
        if case .quote(let info) = segments.first {
            #expect(info.username == "alice")
            #expect(info.postNumber == 3)
            #expect(info.topicId == 123)
            #expect(info.content.contains("This is a quote."))
        } else {
            Issue.record("Expected a quote segment")
        }
    }

    @Test func quoteSegmentsWithSurroundingText() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://example.com")
        let input = """
        Before the quote.
        [quote="bob, post:1, topic:456"]
        Quoted content.
        [/quote]
        After the quote.
        """
        let result = preprocessor.process(input)
        let segments = DiscourseMarkdownPreprocessor.extractSegments(from: result)
        #expect(segments.count == 3)
        if case .markdown(let text) = segments[0] {
            #expect(text.contains("Before the quote."))
        }
        if case .quote(let info) = segments[1] {
            #expect(info.username == "bob")
            #expect(info.topicId == 456)
        }
        if case .markdown(let text) = segments[2] {
            #expect(text.contains("After the quote."))
        }
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

    // MARK: - Onebox parsing tests

    @Test func parseOneboxFromCooked() {
        let cooked = """
        <p>Check this out:</p>
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://www.example.com/">
          <header class="source">
              <img src="https://example.com/favicon.png" class="site-icon" width="32" height="32">
              <a href="https://www.example.com/" target="_blank">example.com</a>
          </header>
          <article class="onebox-body">
            <img src="https://example.com/preview.jpg" class="thumbnail" width="690" height="362">
            <h3><a href="https://www.example.com/" target="_blank">Example Domain</a></h3>
            <p>This domain is for use in illustrative examples.</p>
          </article>
        </aside>
        """
        let oneboxes = DiscourseMarkdownPreprocessor.parseOneboxes(from: cooked)
        #expect(oneboxes.count == 1)
        let info = oneboxes["https://www.example.com"]
        #expect(info?.title == "Example Domain")
        #expect(info?.description == "This domain is for use in illustrative examples.")
        #expect(info?.imageURL == "https://example.com/preview.jpg")
        #expect(info?.faviconURL == "https://example.com/favicon.png")
        #expect(info?.siteName == "example.com")
        #expect(info?.domain == "example.com")
    }

    @Test func richLinkSegmentExtraction() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://forum.example.com")
        let input = """
        Check this out:

        https://www.example.com/

        What do you think?
        """
        let processed = preprocessor.process(input)
        let oneboxes = [
            "https://www.example.com": OneboxInfo(
                url: "https://www.example.com/",
                title: "Example",
                description: "A test site",
                imageURL: nil,
                faviconURL: nil,
                siteName: "example.com"
            )
        ]
        let segments = DiscourseMarkdownPreprocessor.extractSegments(from: processed, oneboxes: oneboxes)
        #expect(segments.count == 3)
        if case .markdown(let text) = segments[0] {
            #expect(text.contains("Check this out"))
        }
        if case .richLink(let info) = segments[1] {
            #expect(info.title == "Example")
        } else {
            Issue.record("Expected a richLink segment")
        }
        if case .markdown(let text) = segments[2] {
            #expect(text.contains("What do you think"))
        }
    }

    @Test func parseGitHubPROneboxWithH4() {
        let cooked = """
        <aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/38698">
          <header class="source">
              <a href="https://github.com/discourse/discourse/pull/38698" target="_blank">github.com/discourse/discourse</a>
          </header>
          <article class="onebox-body">
            <div class="github-info-container">
              <h4><a href="https://github.com/discourse/discourse/pull/38698" target="_blank">DEPS: Bump stripe (#38698)</a></h4>
            </div>
            <p class="github-body-container">Bumps stripe from 11.1.0 to 18.4.2.</p>
          </article>
        </aside>
        """
        let oneboxes = DiscourseMarkdownPreprocessor.parseOneboxes(from: cooked)
        let info = oneboxes["https://github.com/discourse/discourse/pull/38698"]
        #expect(info?.title == "DEPS: Bump stripe (#38698)")
        #expect(info?.description == "Bumps stripe from 11.1.0 to 18.4.2.")
        #expect(info?.siteName == "github.com/discourse/discourse")
    }

    @Test func bareURLWithoutOneboxBecomesMarkdownLink() {
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: "https://forum.example.com")
        let input = """
        Check this:

        https://meta.discourse.org/t/some-topic/12345

        Nice right?
        """
        let processed = preprocessor.process(input)
        let segments = DiscourseMarkdownPreprocessor.extractSegments(from: processed, oneboxes: [:])
        #expect(segments.count == 3)
        if case .markdown(let text) = segments[1] {
            #expect(text.contains("[https://meta.discourse.org/t/some-topic/12345](https://meta.discourse.org/t/some-topic/12345)"))
        } else {
            Issue.record("Expected bare URL converted to markdown link")
        }
    }
}
