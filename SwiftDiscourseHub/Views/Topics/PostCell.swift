#if os(iOS)
import UIKit
import Nuke

/// Pure UIKit collection view cell for rendering a forum post.
/// Uses NSAttributedString for body text — no SwiftUI, no Auto Layout for content measurement.
final class PostCell: UICollectionViewCell {

    // MARK: - Subviews

    let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = PostCellSizeCache.avatarSize / 2
        iv.backgroundColor = .secondarySystemFill
        return iv
    }()

    let nameLabel: UILabel = {
        let l = UILabel()
        let isTablet = UIDevice.current.userInterfaceIdiom == .pad
        l.font = UIFont.preferredFont(forTextStyle: isTablet ? .subheadline : .body).withTraits(.traitBold)
        l.textColor = .label
        return l
    }()

    let usernameLabel: UILabel = {
        let l = UILabel()
        let isTablet = UIDevice.current.userInterfaceIdiom == .pad
        l.font = UIFont.preferredFont(forTextStyle: isTablet ? .subheadline : .body)
        l.textColor = .secondaryLabel
        return l
    }()

    let dateLabel: UILabel = {
        let l = UILabel()
        let isTablet = UIDevice.current.userInterfaceIdiom == .pad
        l.font = UIFont.preferredFont(forTextStyle: isTablet ? .subheadline : .body)
        l.textColor = .secondaryLabel
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }()

    let bodyTextView: UITextView = {
        let storage = NSTextStorage()
        let layoutManager = QuoteBarLayoutManager()
        let container = NSTextContainer(size: .zero)
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        let tv = UITextView(frame: .zero, textContainer: container)
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.backgroundColor = .clear
        tv.dataDetectorTypes = .link
        tv.isSelectable = true
        return tv
    }()

    let likeButton: UIButton = {
        let b = UIButton(type: .system)
        b.tintColor = .secondaryLabel
        b.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIDevice.current.userInterfaceIdiom == .pad ? .caption1 : .subheadline)
        return b
    }()

    let replyCountLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: UIDevice.current.userInterfaceIdiom == .pad ? .caption1 : .subheadline)
        l.textColor = .secondaryLabel
        return l
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        return v
    }()

    // MARK: - State

    var onLike: (() -> Void)?
    private var avatarTask: ImageTask?
    private var imageTasks: [ImageTask] = []
    private var exactSize: CGSize?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarTask?.cancel()
        avatarTask = nil
        imageTasks.forEach { $0.cancel() }
        imageTasks.removeAll()
        avatarImageView.image = nil
        bodyTextView.attributedText = nil
        nameLabel.text = nil
        usernameLabel.text = nil
        dateLabel.text = nil
        likeButton.setTitle(nil, for: .normal)
        replyCountLabel.text = nil
        onLike = nil
        exactSize = nil
    }

    // MARK: - Layout

    private func setupSubviews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(bodyTextView)
        contentView.addSubview(likeButton)
        contentView.addSubview(replyCountLabel)
        contentView.addSubview(separator)

        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        let hPad = PostCellSizeCache.horizontalPadding(for: bounds.width)
        let contentWidth = bounds.width - hPad * 2
        let vPad = PostCellSizeCache.verticalPadding
        let avatarSize = PostCellSizeCache.avatarSize

        var y = vPad

        // Avatar
        avatarImageView.frame = CGRect(x: hPad, y: y, width: avatarSize, height: avatarSize)

        // Name + username stack (to the right of avatar)
        let textX = hPad + avatarSize + PostCellSizeCache.headerSpacing
        let dateSize = dateLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        let nameWidth = bounds.width - textX - hPad - dateSize.width - 8

        let nameHeight = nameLabel.sizeThatFits(CGSize(width: nameWidth, height: .greatestFiniteMagnitude)).height
        let usernameHeight = usernameLabel.sizeThatFits(CGSize(width: nameWidth, height: .greatestFiniteMagnitude)).height
        let totalTextHeight = nameHeight + 1 + usernameHeight
        let textY = y + (avatarSize - totalTextHeight) / 2

        nameLabel.frame = CGRect(x: textX, y: textY, width: nameWidth, height: nameHeight)
        usernameLabel.frame = CGRect(x: textX, y: textY + nameHeight + 1, width: nameWidth, height: usernameHeight)

        // Date label (right-aligned, vertically centered with avatar)
        dateLabel.frame = CGRect(
            x: bounds.width - hPad - dateSize.width,
            y: y + (avatarSize - dateSize.height) / 2,
            width: dateSize.width,
            height: dateSize.height
        )

        y += PostCellSizeCache.headerHeight + PostCellSizeCache.headerToBody

        // Body text
        let bodyHeight: CGFloat
        if let attrText = bodyTextView.attributedText, attrText.length > 0 {
            bodyHeight = PostCellSizeCache.measureHeight(of: attrText, width: contentWidth)
        } else {
            bodyHeight = 0
        }
        bodyTextView.frame = CGRect(x: hPad, y: y, width: contentWidth, height: bodyHeight)

        y += bodyHeight + PostCellSizeCache.bodyToFooter

        // Footer
        let footerHeight = PostCellSizeCache.footerHeight
        likeButton.sizeToFit()
        likeButton.frame = CGRect(x: hPad, y: y, width: max(likeButton.bounds.width, 44), height: footerHeight)

        let replySize = replyCountLabel.sizeThatFits(CGSize(width: contentWidth, height: footerHeight))
        replyCountLabel.frame = CGRect(
            x: likeButton.frame.maxX + 16,
            y: y,
            width: replySize.width,
            height: footerHeight
        )

        // Separator
        separator.frame = CGRect(
            x: 0,
            y: bounds.height - PostCellSizeCache.separatorHeight,
            width: bounds.width,
            height: PostCellSizeCache.separatorHeight
        )
    }

    // Bypass Auto Layout measurement when exact size is known
    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        if let exactSize {
            layoutAttributes.size = exactSize
            return layoutAttributes
        }
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }

    // MARK: - Configure

    func configure(
        post: Post,
        measured: PostCellSizeCache.MeasuredPost?,
        baseURL: String,
        isLiked: Bool,
        availableWidth: CGFloat
    ) {
        let displayName = post.name?.isEmpty == false ? post.name : post.username
        nameLabel.text = displayName ?? "Unknown"
        usernameLabel.text = post.username.map { "@\($0)" }
        dateLabel.text = Self.formatDate(post.createdAt, postNumber: post.postNumber)

        // Body
        if let measured {
            bodyTextView.attributedText = measured.attributedBody
            exactSize = CGSize(width: availableWidth, height: measured.totalHeight)
        } else {
            bodyTextView.attributedText = nil
            exactSize = nil
        }

        // Load inline images
        loadInlineImages()

        // Like button
        configureLikeButton(post: post, isLiked: isLiked)

        // Reply count
        if let replies = post.replyCount, replies > 0 {
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "arrowshape.turn.up.left")?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
            let font = replyCountLabel.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
            let imageSize = font.pointSize * 1.2
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - imageSize) / 2, width: imageSize, height: imageSize)
            let str = NSMutableAttributedString(attachment: attachment)
            str.append(NSAttributedString(string: " \(replies)", attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]))
            replyCountLabel.attributedText = str
        } else {
            replyCountLabel.attributedText = nil
        }

        // Avatar
        loadAvatar(template: post.avatarTemplate, baseURL: baseURL)
    }

    private func configureLikeButton(post: Post, isLiked: Bool) {
        let heartImage = UIImage(systemName: isLiked ? "heart.fill" : "heart")
        likeButton.setImage(heartImage, for: .normal)
        likeButton.tintColor = isLiked ? .systemRed : .secondaryLabel

        let count = post.likeCount
        if count > 0 {
            likeButton.setTitle(" \(count)", for: .normal)
        } else {
            likeButton.setTitle(nil, for: .normal)
        }

        likeButton.isHidden = !post.canLike && post.likeCount == 0
    }

    private func loadInlineImages() {
        guard let attrText = bodyTextView.attributedText else { return }
        let fullRange = NSRange(location: 0, length: attrText.length)

        attrText.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? ScalableImageAttachment,
                  let urlString = attachment.imageURL,
                  let url = URL(string: urlString) else { return }

            let task = ImagePipeline.shared.loadImage(with: url) { [weak self] result in
                guard let self else { return }
                if case .success(let response) = result {
                    attachment.image = response.image
                    // Trigger text view to redraw with the loaded image
                    let current = self.bodyTextView.attributedText
                    self.bodyTextView.attributedText = current
                    self.bodyTextView.layoutManager.invalidateDisplay(forCharacterRange: range)
                }
            }
            imageTasks.append(task)
        }
    }

    private func loadAvatar(template: String?, baseURL: String) {
        guard let url = URLHelpers.avatarURL(template: template, size: 90, baseURL: baseURL) else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            return
        }
        avatarTask = ImagePipeline.shared.loadImage(with: url) { [weak self] result in
            if case .success(let response) = result {
                self?.avatarImageView.image = response.image
            }
        }
    }

    // MARK: - Date Formatting

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func formatDate(_ dateString: String?, postNumber: Int?) -> String {
        var parts: [String] = []

        if let dateString,
           let date = isoFormatter.date(from: dateString) ?? isoFormatterNoFrac.date(from: dateString) {
            let seconds = -date.timeIntervalSinceNow
            if seconds < 60 {
                parts.append("\(Int(seconds))s ago")
            } else if seconds < 3600 {
                parts.append("\(Int(seconds / 60))m ago")
            } else if seconds < 86400 {
                parts.append("\(Int(seconds / 3600))h ago")
            } else if seconds < 86400 * 7 {
                parts.append("\(Int(seconds / 86400))d ago")
            } else {
                let formatter = DateFormatter()
                if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: .now) {
                    formatter.dateFormat = "MMM d"
                } else {
                    formatter.dateFormat = "MMM d, yyyy"
                }
                parts.append(formatter.string(from: date))
            }
        }

        if let pn = postNumber {
            parts.append("#\(pn)")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    @objc private func likeTapped() {
        onLike?()
    }
}

// MARK: - UIFont helper

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif
