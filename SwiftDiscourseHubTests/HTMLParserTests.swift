import Testing
import Foundation

@testable import SwiftDiscourseHub

@MainActor struct HTMLParserTests {

    let parser = DiscourseHTMLParser(baseURL: "https://meta.discourse.org")

    // MARK: - Image tests

    @Test func imageTagProducesImageURLAttribute() throws {
        let html = """
        <p>Here is an image:</p>
        <p><img src="https://example.com/photo.png" alt="A photo" width="690" height="400"></p>
        """
        let result = try parser.attributedString(for: html)

        var foundImageURL = false
        for run in result.runs {
            if let imageURL = run.imageURL {
                foundImageURL = true
                #expect(imageURL.absoluteString == "https://example.com/photo.png",
                        "Image URL should match src: \(imageURL)")
            }
        }
        #expect(foundImageURL, "Should find at least one run with imageURL attribute")
    }

    @Test func relativeImageURLIsResolved() throws {
        let html = """
        <p><img src="/uploads/default/original/1X/abc123.png" alt="upload"></p>
        """
        let result = try parser.attributedString(for: html)

        var foundImageURL: URL?
        for run in result.runs {
            if let url = run.imageURL {
                foundImageURL = url
            }
        }
        #expect(foundImageURL != nil, "Should find imageURL attribute")
        #expect(foundImageURL?.absoluteString == "https://meta.discourse.org/uploads/default/original/1X/abc123.png",
                "Relative URL should be resolved against baseURL: \(foundImageURL?.absoluteString ?? "nil")")
    }

    @Test func protocolRelativeImageURLIsResolved() throws {
        let html = """
        <p><img src="//cdn.example.com/image.jpg" alt="cdn image"></p>
        """
        let result = try parser.attributedString(for: html)

        var foundImageURL: URL?
        for run in result.runs {
            if let url = run.imageURL {
                foundImageURL = url
            }
        }
        #expect(foundImageURL != nil, "Should find imageURL attribute")
        #expect(foundImageURL?.absoluteString == "https://cdn.example.com/image.jpg",
                "Protocol-relative URL should get https: prefix: \(foundImageURL?.absoluteString ?? "nil")")
    }

    @Test func emojiImageBecomesText() throws {
        let html = """
        <p>Hello <img src="https://emoji.discourse-cdn.com/twitter/wave.png" title=":wave:" class="emoji" alt=":wave:"> world</p>
        """
        let result = try parser.attributedString(for: html)
        let text = String(result.characters)

        // Emoji images should NOT produce imageURL, they should be inline text
        var hasImageURL = false
        for run in result.runs {
            if run.imageURL != nil {
                hasImageURL = true
            }
        }
        #expect(!hasImageURL, "Emoji images should not produce imageURL attribute")
        #expect(text.contains(":wave:"), "Emoji alt text should be preserved: \(text)")
    }

    @Test func multipleImagesInPost() throws {
        let html = """
        <p>First image:</p>
        <p><img src="https://example.com/one.png" alt="one"></p>
        <p>Second image:</p>
        <p><img src="https://example.com/two.jpg" alt="two"></p>
        """
        let result = try parser.attributedString(for: html)

        var imageURLs: [URL] = []
        for run in result.runs {
            if let url = run.imageURL {
                imageURLs.append(url)
            }
        }
        #expect(imageURLs.count == 2, "Should find 2 images, got \(imageURLs.count)")
        #expect(imageURLs.contains(where: { $0.absoluteString == "https://example.com/one.png" }))
        #expect(imageURLs.contains(where: { $0.absoluteString == "https://example.com/two.jpg" }))
    }

    @Test func discourseUploadedImageInLightbox() throws {
        // Discourse wraps uploaded images in lightbox anchors
        let html = """
        <p><a class="lightbox" href="https://meta.discourse.org/uploads/original/abc.png"><img src="https://meta.discourse.org/uploads/optimized/abc_2_690x400.png" alt="screenshot" width="690" height="400"></a></p>
        """
        let result = try parser.attributedString(for: html)

        var foundImageURL = false
        for run in result.runs {
            if run.imageURL != nil {
                foundImageURL = true
            }
        }
        #expect(foundImageURL, "Image inside lightbox anchor should still produce imageURL")
    }

    // MARK: - Basic content tests

    @Test func paragraphTextIsPreserved() throws {
        let html = "<p>Hello world</p>"
        let result = try parser.attributedString(for: html)
        let text = String(result.characters)
        #expect(text.contains("Hello world"))
    }

    @Test func boldTextHasStrongIntent() throws {
        let html = "<p><strong>bold text</strong></p>"
        let result = try parser.attributedString(for: html)

        var foundStrong = false
        for run in result.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) {
                foundStrong = true
                let text = String(result[run.range].characters)
                #expect(text.contains("bold"))
            }
        }
        #expect(foundStrong, "Should find stronglyEmphasized inline intent")
    }

    @Test func codeBlockHasLanguageHint() throws {
        let html = """
        <pre><code class="lang-ruby">puts "hello"</code></pre>
        """
        let result = try parser.attributedString(for: html)

        var foundCodeBlock = false
        for run in result.runs {
            if let intent = run.presentationIntent {
                for component in intent.components {
                    if case .codeBlock(let lang) = component.kind {
                        foundCodeBlock = true
                        #expect(lang == "ruby", "Language hint should be 'ruby', got: \(lang ?? "nil")")
                    }
                }
            }
        }
        #expect(foundCodeBlock, "Should find codeBlock presentation intent")
    }

    @Test func imageHasBothImageURLAndPresentationIntent() throws {
        let html = """
        <p>Look at this: <img src="https://example.com/photo.png" alt="photo"></p>
        """
        let result = try parser.attributedString(for: html)

        var foundImageWithIntent = false
        for run in result.runs {
            if let imageURL = run.imageURL {
                // This run should also have a presentationIntent (paragraph)
                let hasIntent = run.presentationIntent != nil
                #expect(hasIntent, "Image run should have presentationIntent set")
                foundImageWithIntent = true
                #expect(imageURL.absoluteString == "https://example.com/photo.png")
            }
        }
        #expect(foundImageWithIntent, "Should find image run with both attributes")
    }

    @Test func imageRunContainsValues() throws {
        // Verify containsValues works the same way Textual checks
        let html = """
        <p><img src="https://example.com/test.png" alt="test"></p>
        """
        let result = try parser.attributedString(for: html)

        // This is what WithAttachments checks
        let hasImageURLValues = result.runs.contains { $0.imageURL != nil }
        #expect(hasImageURLValues, "AttributedString should contain imageURL values")
    }

    @Test func realDiscourseImageHTMLProducesImageURL() throws {
        // Real HTML from a Discourse post with an uploaded image
        let html = """
        <p><a href="https://meta.discourse.org/uploads/original/abc.png" target="_blank" rel="noopener nofollow ugc"><img src="https://d11a6trkgmumsb.cloudfront.net/optimized/4X/b/3/c/b3cebc5c1db5f8772f5b84d72bb2d8cb0a4c1d5c_2_690x344.png" alt="screenshot" data-base62-sha1="abc123" width="690" height="344" class="animated"></a></p>
        """
        let result = try parser.attributedString(for: html)

        // Debug: print all runs and their attributes
        var imageURLs: [URL] = []
        for run in result.runs {
            let text = String(result[run.range].characters)
            let hasImage = run.imageURL != nil
            let hasLink = run.link != nil
            let hasIntent = run.presentationIntent != nil
            if hasImage {
                imageURLs.append(run.imageURL!)
            }
            // Print for debugging
            print("Run: '\(text)' imageURL=\(hasImage) link=\(hasLink) intent=\(hasIntent)")
        }

        #expect(!imageURLs.isEmpty, "Should find imageURL in real Discourse image HTML. Runs: \(result.runs.map { String(result[$0.range].characters) })")
    }

    @Test func openAILightboxImageProducesImageURL() throws {
        let html = """
        <div class="lightbox-wrapper"><a class="lightbox" href="https://us1.discourse-cdn.com/openai1/original/4X/b/7/6/b768555cb833eea6bb6ffd1d8a0cdb6a3b25e73f.jpeg" data-download-href="/uploads/short-url/test.jpeg?dl=1" title="1000021541"><img src="https://us1.discourse-cdn.com/openai1/optimized/4X/b/7/6/b768555cb833eea6bb6ffd1d8a0cdb6a3b25e73f_2_690x460.jpeg" alt="1000021541" data-base62-sha1="qauUrQlAXnLu8OF7ScSHSskLtiD" width="690" height="460"><div class="meta"><svg class="fa d-icon d-icon-far-image" xmlns="http://www.w3.org/2000/svg"><use href="#far-image"></use></svg><span class="filename">1000021541</span><span class="informations">1024×683 109 KB</span><svg class="fa d-icon d-icon-discourse-expand" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-expand"></use></svg></div></a></div>
        """
        let parser = DiscourseHTMLParser(baseURL: "https://community.openai.com")
        let result = try parser.attributedString(for: html)

        var imageURLs: [URL] = []
        for run in result.runs {
            if let url = run.imageURL {
                imageURLs.append(url)
            }
            let text = String(result[run.range].characters)
            let hasImage = run.imageURL != nil
            let hasLink = run.link != nil
            print("Run: '\(text.prefix(40))' imageURL=\(hasImage) link=\(hasLink)")
        }
        #expect(!imageURLs.isEmpty, "Lightbox-wrapped image should produce imageURL")
        if let first = imageURLs.first {
            #expect(first.absoluteString.contains("b768555cb833eea6"), "Should use the img src URL")
        }
    }

    @Test func oneboxRendersAsLinkToSource() throws {
        let html = """
        <aside class="onebox githubissue" data-onebox-src="https://github.com/openai/codex/issues/14396">
          <header class="source">
            <a href="https://github.com/openai/codex/issues/14396" target="_blank" rel="noopener">github.com/openai/codex</a>
          </header>
          <article class="onebox-body">
            <div class="github-row">
              <div class="github-info-container">
                <h4><a href="https://github.com/openai/codex/issues/14396" target="_blank" rel="noopener">Codex Desktop App — failed to resume task</a></h4>
              </div>
            </div>
          </article>
        </aside>
        """
        let parser = DiscourseHTMLParser(baseURL: "https://community.openai.com")
        let result = try parser.attributedString(for: html)
        let text = String(result.characters)

        // Should contain the onebox source URL as text
        #expect(text.contains("github.com/openai/codex/issues/14396"),
                "Onebox should render source URL: \(text)")

        // Should have a link pointing to the source
        var linkURL: URL?
        for run in result.runs {
            if let url = run.link { linkURL = url }
        }
        #expect(linkURL?.absoluteString == "https://github.com/openai/codex/issues/14396",
                "Onebox link should point to data-onebox-src")
    }

    @Test func horizontalRuleRendersAsThematicBreak() throws {
        let html = "<p>Before</p><hr><p>After</p>"
        let result = try parser.attributedString(for: html)
        let text = String(result.characters)

        #expect(text.contains("Before"))
        #expect(text.contains("After"))

        var hasThematicBreak = false
        for run in result.runs {
            if let intent = run.presentationIntent {
                for component in intent.components {
                    if case .thematicBreak = component.kind {
                        hasThematicBreak = true
                    }
                }
            }
        }
        #expect(hasThematicBreak, "Should have thematicBreak intent for <hr>")
    }

    @Test func inlineImageAfterTextRendersCorrectly() throws {
        // This is the pattern from the OpenAI post — a paragraph with text then an image
        let html = """
        <p>which has been noticed by OpenAI staff</p>
        <p><img src="https://us1.discourse-cdn.com/openai1/original/4X/7/6/3/763ac9c3daf3fd5899ddb8d9d97062166d338bef.png" alt="image" width="326" height="43"></p>
        """
        let parser = DiscourseHTMLParser(baseURL: "https://community.openai.com")
        let result = try parser.attributedString(for: html)

        #expect(String(result.characters).contains("noticed by OpenAI staff"))

        var hasImage = false
        for run in result.runs {
            if run.imageURL != nil { hasImage = true }
        }
        #expect(hasImage, "Should have imageURL for the screenshot")
    }

    @Test func fullPost9FromOpenAIRendersAllContent() throws {
        // Simplified version of post #9 HTML
        let html = """
        <p>For those reporting the problem here.</p>
        <p>You are more than welcome to report such problems here.</p>
        <p>For persistent issues consider the <a href="https://github.com/openai/codex/issues">GitHub OpenAI Codex issue</a> tab.</p>
        <p>Search for your issue first and if you find it give the first post a thumbs up.</p>
        <p>If your issue is not a duplicate then report it as a new issue.</p>
        <hr>
        <p>I do not have a Mac so can not test this.</p>
        <aside class="onebox githubissue" data-onebox-src="https://github.com/openai/codex/issues/14396">
          <header class="source">
            <a href="https://github.com/openai/codex/issues/14396" target="_blank">github.com/openai/codex</a>
          </header>
          <article class="onebox-body">
            <div class="github-row">
              <div class="github-info-container">
                <h4><a href="https://github.com/openai/codex/issues/14396" target="_blank">Codex Desktop App — failed to resume task</a></h4>
                <div class="labels">
                  <span>bug</span>
                  <span>app</span>
                </div>
              </div>
            </div>
          </article>
        </aside>
        <p>which has been noticed by OpenAI staff</p>
        <p><img src="https://example.com/screenshot.png" alt="image" width="326" height="43"></p>
        """
        let parser = DiscourseHTMLParser(baseURL: "https://community.openai.com")
        let result = try parser.attributedString(for: html)
        let text = String(result.characters)

        // All key content should be present
        #expect(text.contains("reporting the problem"), "Should have opening paragraph")
        #expect(text.contains("GitHub OpenAI Codex issue"), "Should have link text")
        #expect(text.contains("not have a Mac"), "Should have paragraph after hr")
        #expect(text.contains("github.com/openai/codex/issues/14396"), "Should have onebox source URL")
        #expect(text.contains("noticed by OpenAI staff"), "Should have closing paragraph")

        // Should have image
        var hasImage = false
        for run in result.runs { if run.imageURL != nil { hasImage = true } }
        #expect(hasImage, "Should have screenshot image")

        // Should have links
        var linkURLs: [String] = []
        for run in result.runs {
            if let url = run.link { linkURLs.append(url.absoluteString) }
        }
        #expect(linkURLs.contains("https://github.com/openai/codex/issues"), "Should have GitHub issues link")
        #expect(linkURLs.contains("https://github.com/openai/codex/issues/14396"), "Should have onebox link")

        // Should have thematic break
        var hasHR = false
        for run in result.runs {
            if let intent = run.presentationIntent {
                for c in intent.components where c.kind == .thematicBreak { hasHR = true }
            }
        }
        #expect(hasHR, "Should have thematic break for <hr>")
    }

    @Test func linkHasURLAttribute() throws {
        let html = """
        <p>Visit <a href="https://discourse.org">Discourse</a></p>
        """
        let result = try parser.attributedString(for: html)

        var foundLink = false
        for run in result.runs {
            if let link = run.link {
                foundLink = true
                #expect(link.absoluteString == "https://discourse.org")
            }
        }
        #expect(foundLink, "Should find link attribute")
    }
}
