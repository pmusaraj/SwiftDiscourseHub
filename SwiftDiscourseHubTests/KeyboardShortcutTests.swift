import Testing
import Foundation

#if os(macOS)
import AppKit

@testable import SwiftDiscourseHub

@MainActor struct KeyboardShortcutTests {

    @Test func editableTextViewIsTextInput() {
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        #expect(KeyboardHelper.isTextInput(textView) == true)
    }

    @Test func readOnlyTextViewIsNotTextInput() {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        #expect(KeyboardHelper.isTextInput(textView) == false)
    }

    @Test func textFieldIsTextInput() {
        let textField = NSTextField()
        textField.isEditable = true
        #expect(KeyboardHelper.isTextInput(textField) == true)
    }

    @Test func readOnlyTextFieldIsNotTextInput() {
        let textField = NSTextField()
        textField.isEditable = false
        #expect(KeyboardHelper.isTextInput(textField) == false)
    }

    @Test func nonTextResponderIsNotTextInput() {
        let button = NSButton()
        #expect(KeyboardHelper.isTextInput(button) == false)
    }

    @Test func nilResponderIsNotTextInput() {
        #expect(KeyboardHelper.isTextInput(nil) == false)
    }
}

#endif
