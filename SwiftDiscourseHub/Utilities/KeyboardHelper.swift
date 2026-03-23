#if os(macOS)
import AppKit

enum KeyboardHelper {
    /// Returns true if the given responder is a user-editable text input
    /// (not a read-only NSTextView used for content display).
    static func isTextInput(_ responder: NSResponder?) -> Bool {
        guard let responder else { return false }
        if let textView = responder as? NSTextView {
            return textView.isEditable
        }
        if let textField = responder as? NSTextField {
            return textField.isEditable
        }
        return false
    }
}
#endif
