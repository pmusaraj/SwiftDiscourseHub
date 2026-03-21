#if os(iOS)
import UIKit
import Markdown

/// Pre-measures post cell heights using Markdownosaur-rendered NSAttributedString.
/// Results are cached by post number.
final class PostCellSizeCache: @unchecked Sendable {

    struct MeasuredPost: @unchecked Sendable {
        let postNumber: Int
        let attributedBody: NSAttributedString
        let bodyHeight: CGFloat
        let totalHeight: CGFloat
    }

    // MARK: - Configuration

    static let avatarSize: CGFloat = 36
    static let headerSpacing: CGFloat = 8
    static let headerToBody: CGFloat = 16
    static let bodyToFooter: CGFloat = 16
    static let footerHeight: CGFloat = 20
    static let verticalPadding: CGFloat = 18
    static let horizontalPaddingCompact: CGFloat = 24
    static let horizontalPaddingRegular: CGFloat = 48
    static let regularWidthBreakpoint: CGFloat = 700
    nonisolated(unsafe) static let separatorHeight: CGFloat = {
        MainActor.assumeIsolated { 1.0 / UIScreen.main.scale }
    }()

    static func horizontalPadding(for width: CGFloat) -> CGFloat {
        width > regularWidthBreakpoint ? horizontalPaddingRegular : horizontalPaddingCompact
    }

    static let headerHeight: CGFloat = avatarSize

    // MARK: - Fonts

    nonisolated(unsafe) static let bodyFont: UIFont = {
        let isTablet = MainActor.assumeIsolated { UIDevice.current.userInterfaceIdiom == .pad }
        let style: UIFont.TextStyle = isTablet ? .subheadline : .body
        return UIFont.preferredFont(forTextStyle: style)
    }()

    // MARK: - Cache

    private let lock = NSLock()
    private var cache: [Int: MeasuredPost] = [:]

    func get(_ postNumber: Int) -> MeasuredPost? {
        lock.lock()
        defer { lock.unlock() }
        return cache[postNumber]
    }

    func set(_ measured: MeasuredPost) {
        lock.lock()
        defer { lock.unlock() }
        cache[measured.postNumber] = measured
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    // MARK: - Measurement

    func measure(postNumber: Int, markdown: String, availableWidth: CGFloat) -> MeasuredPost {
        if let cached = get(postNumber) {
            return cached
        }

        let hPad = Self.horizontalPadding(for: availableWidth)
        let bodyWidth = availableWidth - hPad * 2

        let attrString = Self.renderMarkdown(markdown)
        let bodyHeight = Self.measureHeight(of: attrString, width: bodyWidth)

        let totalHeight = Self.verticalPadding
            + Self.headerHeight
            + Self.headerToBody
            + bodyHeight
            + Self.bodyToFooter
            + Self.footerHeight
            + Self.verticalPadding
            + Self.separatorHeight

        let measured = MeasuredPost(
            postNumber: postNumber,
            attributedBody: attrString,
            bodyHeight: bodyHeight,
            totalHeight: totalHeight
        )
        set(measured)
        return measured
    }

    // MARK: - Markdown Rendering

    static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let document = Document(parsing: markdown)
        var renderer = Markdownosaur(
            baseFont: bodyFont,
            bodyColor: .label,
            codeColor: .label,
            codeBgColor: .secondarySystemFill,
            linkColor: .systemBlue,
            quoteColor: .secondaryLabel
        )
        return renderer.attributedString(from: document)
    }

    static func measureHeight(of attrString: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(boundingRect.height)
    }
}
#endif
