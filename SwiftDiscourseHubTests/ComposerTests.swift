import Testing
import Foundation

@testable import SwiftDiscourseHub

@Suite struct MarkdownFormatterTests {
    @Test func boldWrapsText() {
        let result = MarkdownFormatter.bold("hello")
        #expect(result == "**hello**")
    }

    @Test func boldEmptyInsertsPlaceholder() {
        let result = MarkdownFormatter.bold("")
        #expect(result == "**bold text**")
    }

    @Test func boldToggleRemovesWrapping() {
        let result = MarkdownFormatter.bold("**hello**")
        #expect(result == "hello")
    }

    @Test func italicWrapsText() {
        let result = MarkdownFormatter.italic("hello")
        #expect(result == "*hello*")
    }

    @Test func italicEmptyInsertsPlaceholder() {
        let result = MarkdownFormatter.italic("")
        #expect(result == "*italic text*")
    }

    @Test func linkInsertsTemplate() {
        let result = MarkdownFormatter.link("")
        #expect(result == "[link text](url)")
    }

    @Test func linkAppendsToText() {
        let result = MarkdownFormatter.link("existing text ")
        #expect(result == "existing text [link text](url)")
    }

    @Test func quotePrependsToLines() {
        let result = MarkdownFormatter.quote("line one\nline two")
        #expect(result == "> line one\n> line two")
    }

    @Test func quoteToggleRemovesPrefix() {
        let result = MarkdownFormatter.quote("> line one\n> line two")
        #expect(result == "line one\nline two")
    }

    @Test func quoteEmptyInsertsPrefix() {
        let result = MarkdownFormatter.quote("")
        #expect(result == "> ")
    }

    @Test func emptyTextCannotSubmit() {
        let text = "   \n  "
        let canSubmit = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(!canSubmit)
    }

    @Test func nonEmptyTextCanSubmit() {
        let text = "Hello world"
        let canSubmit = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(canSubmit)
    }
}
