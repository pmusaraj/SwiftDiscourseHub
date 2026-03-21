#if os(iOS)
import UIKit
import SwiftUI
import ChatLayout
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "ChatLayoutPostStream")

/// UICollectionView wrapper using ChatLayout for bidirectional post stream scrolling.
/// Uses pure UIKit PostCell with pre-measured NSAttributedString content for performance.
struct ChatLayoutPostStreamView: UIViewRepresentable {

    // MARK: - Data

    let items: [StreamItem]
    let postMarkdown: [Int: String]
    let avatarLookup: [String: String]
    let baseURL: String
    let contentWidth: CGFloat
    let topicId: Int
    let likedPostIds: Set<Int>
    let isAuthenticated: Bool
    var topInset: CGFloat = 0

    // MARK: - Scroll request

    var scrollToPostId: Int?
    var scrollAnchor: UICollectionView.ScrollPosition = .centeredVertically

    // MARK: - Callbacks

    var onLike: ((Post) async -> Void)?
    var onQuote: ((String, Post) -> Void)?
    var onScrollToPost: ((Int) -> Void)?
    var onLoadOlder: (() -> Void)?
    var onLoadNewer: (() -> Void)?
    var canLoadOlder: Bool = false
    var canLoadNewer: Bool = false
    var isLoadingOlder: Bool = false
    var isLoadingNewer: Bool = false
    var onScrollChange: ((_ offset: CGFloat, _ contentHeight: CGFloat, _ containerHeight: CGFloat) -> Void)?
    var onScrollConsumed: (() -> Void)?

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let chatLayout = CollectionViewChatLayout()
        chatLayout.settings.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
        chatLayout.settings.interItemSpacing = 0
        chatLayout.settings.interSectionSpacing = 0
        chatLayout.delegate = context.coordinator

        let cv = UICollectionView(frame: .zero, collectionViewLayout: chatLayout)
        cv.backgroundColor = .clear
        cv.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 100, right: 0)
        cv.showsVerticalScrollIndicator = false
        cv.delegate = context.coordinator

        let postCellReg = UICollectionView.CellRegistration<PostCell, StreamItem> {
            [weak coord = context.coordinator] cell, indexPath, item in
            guard let coord else { return }
            coord.configurePostCell(cell, item: item, indexPath: indexPath)
        }

        let placeholderCellReg = UICollectionView.CellRegistration<UICollectionViewCell, StreamItem> {
            cell, _, item in
            if case .placeholder(_, let count) = item {
                cell.contentConfiguration = UIHostingConfiguration {
                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                            Text("^[\(count) earlier post](inflect: true)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 500)
                    .background(Color.blue.opacity(0.07))
                }
                .margins(.all, 0)
            }
        }

        let ds = UICollectionViewDiffableDataSource<Int, StreamItem>(collectionView: cv) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item {
            case .post:
                return collectionView.dequeueConfiguredReusableCell(using: postCellReg, for: indexPath, item: item)
            case .placeholder:
                return collectionView.dequeueConfiguredReusableCell(using: placeholderCellReg, for: indexPath, item: item)
            }
        }

        let coord = context.coordinator
        coord.collectionView = cv
        coord.chatLayout = chatLayout
        coord.dataSource = ds
        coord.updateFrom(self)

        // Pre-measure all initial items
        coord.preMeasureItems(items, markdown: postMarkdown, width: contentWidth)

        var snap = NSDiffableDataSourceSnapshot<Int, StreamItem>()
        snap.appendSections([0])
        snap.appendItems(items)
        ds.apply(snap, animatingDifferences: false)
        coord.currentItemIds = items.map(\.id)

        // Start with first post aligned to bottom of topic header
        cv.contentOffset = CGPoint(x: 0, y: -topInset)

        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        let coord = context.coordinator
        coord.updateFrom(self)

        let expectedTopInset = topInset
        if cv.contentInset.top != expectedTopInset {
            cv.contentInset.top = expectedTopInset
        }

        // Pre-measure any new markdown that arrived
        coord.preMeasureItems(items, markdown: postMarkdown, width: contentWidth)

        let oldIds = coord.currentItemIds
        let newIds = items.map(\.id)

        if oldIds != newIds {
            let isPrepend: Bool = {
                guard let oldFirst = oldIds.first,
                      let newFirst = newIds.first,
                      oldFirst != newFirst else { return false }
                return newIds.contains(oldFirst)
            }()

            var snap = NSDiffableDataSourceSnapshot<Int, StreamItem>()
            snap.appendSections([0])
            snap.appendItems(items)

            if isPrepend, let chatLayout = coord.chatLayout {
                // Find the first visible cell's index path and its offset from the top
                // so we can restore exactly that position after prepend.
                let visibleCells = cv.visibleCells.compactMap { cv.indexPath(for: $0) }.sorted()
                let topInset = cv.contentInset.top
                var anchorIndexPath: IndexPath?
                var anchorOffset: CGFloat = 0

                for ip in visibleCells {
                    if let attrs = cv.layoutAttributesForItem(at: ip) {
                        let cellTop = attrs.frame.origin.y - cv.contentOffset.y - topInset
                        if cellTop >= -attrs.frame.height {
                            anchorIndexPath = ip
                            anchorOffset = cv.contentOffset.y - attrs.frame.origin.y + topInset
                            break
                        }
                    }
                }

                // Remember which item ID was anchored
                let anchorItemId: String? = {
                    guard let ip = anchorIndexPath, ip.item < oldIds.count else { return nil }
                    return oldIds[ip.item]
                }()

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                coord.dataSource?.apply(snap, animatingDifferences: false)
                cv.layoutIfNeeded()
                CATransaction.commit()

                // Restore: find the anchor item in the new snapshot and scroll to it
                if let anchorId = anchorItemId,
                   let newIdx = newIds.firstIndex(of: anchorId) {
                    let snapshot = ChatLayoutPositionSnapshot(
                        indexPath: IndexPath(item: newIdx, section: 0),
                        edge: .top,
                        offset: anchorOffset
                    )
                    chatLayout.restoreContentOffset(with: snapshot)
                }
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                coord.dataSource?.apply(snap, animatingDifferences: false)
                cv.layoutIfNeeded()
                CATransaction.commit()
            }

            coord.currentItemIds = newIds
        } else {
            // Reconfigure existing cells (e.g. markdown arrived for a post)
            if let ds = coord.dataSource {
                var snap = ds.snapshot()
                snap.reconfigureItems(snap.itemIdentifiers)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                ds.apply(snap, animatingDifferences: false)
                CATransaction.commit()
            }
        }

        // Handle scroll-to request
        if let targetId = scrollToPostId, targetId != coord.lastScrolledToId {
            let targetItemId = "post-\(targetId)"
            if let idx = items.firstIndex(where: { $0.id == targetItemId }),
               let chatLayout = coord.chatLayout {
                let indexPath = IndexPath(item: idx, section: 0)

                let visibleHeight = cv.bounds.height - cv.contentInset.top - cv.contentInset.bottom
                let edge: ChatLayoutPositionSnapshot.Edge = scrollAnchor == .bottom ? .bottom : .top
                let offset: CGFloat = scrollAnchor == .centeredVertically ? visibleHeight / 3 : 0

                let snapshot = ChatLayoutPositionSnapshot(
                    indexPath: indexPath,
                    edge: edge,
                    offset: offset
                )
                chatLayout.restoreContentOffset(with: snapshot)

                coord.lastScrolledToId = targetId
                DispatchQueue.main.async { [onScrollConsumed] in
                    onScrollConsumed?()
                }
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICollectionViewDelegate, ChatLayoutDelegate {
        weak var collectionView: UICollectionView?
        var chatLayout: CollectionViewChatLayout?
        var dataSource: UICollectionViewDiffableDataSource<Int, StreamItem>?
        var currentItemIds: [String] = []
        var lastScrolledToId: Int?
        var lastLoadOlderTime: CFTimeInterval = 0
        var lastLoadNewerTime: CFTimeInterval = 0
        private let loadCooldown: CFTimeInterval = 2.0

        let sizeCache = PostCellSizeCache()

        var items: [StreamItem] = []
        var postMarkdown: [Int: String] = [:]
        var avatarLookup: [String: String] = [:]
        var baseURL: String = ""
        var contentWidth: CGFloat = 0
        var topicId: Int = 0
        var likedPostIds: Set<Int> = []
        var isAuthenticated: Bool = false

        var onLike: ((Post) async -> Void)?
        var onQuote: ((String, Post) -> Void)?
        var onScrollToPost: ((Int) -> Void)?
        var onLoadOlder: (() -> Void)?
        var onLoadNewer: (() -> Void)?
        var canLoadOlder: Bool = false
        var canLoadNewer: Bool = false
        var isLoadingOlder: Bool = false
        var isLoadingNewer: Bool = false
        var onScrollChange: ((_ offset: CGFloat, _ contentHeight: CGFloat, _ containerHeight: CGFloat) -> Void)?

        func updateFrom(_ parent: ChatLayoutPostStreamView) {
            items = parent.items
            postMarkdown = parent.postMarkdown
            avatarLookup = parent.avatarLookup
            baseURL = parent.baseURL
            contentWidth = parent.contentWidth
            topicId = parent.topicId
            likedPostIds = parent.likedPostIds
            isAuthenticated = parent.isAuthenticated
            onLike = parent.onLike
            onQuote = parent.onQuote
            onScrollToPost = parent.onScrollToPost
            onLoadOlder = parent.onLoadOlder
            onLoadNewer = parent.onLoadNewer
            canLoadOlder = parent.canLoadOlder
            canLoadNewer = parent.canLoadNewer
            isLoadingOlder = parent.isLoadingOlder
            isLoadingNewer = parent.isLoadingNewer
            onScrollChange = parent.onScrollChange
        }

        /// Pre-measure posts that have markdown available
        func preMeasureItems(_ items: [StreamItem], markdown: [Int: String], width: CGFloat) {
            guard width > 0 else { return }
            for item in items {
                if case .post(let post) = item,
                   let pn = post.postNumber,
                   let md = markdown[pn],
                   sizeCache.get(pn) == nil {
                    _ = sizeCache.measure(postNumber: pn, markdown: md, availableWidth: width)
                }
            }
        }

        func configurePostCell(_ cell: PostCell, item: StreamItem, indexPath: IndexPath) {
            guard case .post(let post) = item else { return }
            let pn = post.postNumber ?? 0
            let measured = sizeCache.get(pn)
            let isLiked = likedPostIds.contains(post.id) || post.hasLiked

            cell.configure(
                post: post,
                measured: measured,
                baseURL: baseURL,
                isLiked: isLiked,
                availableWidth: contentWidth
            )

            if post.canLike {
                cell.onLike = { [weak self] in
                    guard let self, let onLike = self.onLike else { return }
                    Task { await onLike(post) }
                }
            }
        }

        // MARK: - ChatLayoutDelegate

        func sizeForItem(_ chatLayout: CollectionViewChatLayout, of kind: ItemKind, at indexPath: IndexPath) -> ItemSize {
            guard indexPath.item < items.count else {
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 200))
            }

            switch items[indexPath.item] {
            case .post(let post):
                if let pn = post.postNumber, let measured = sizeCache.get(pn) {
                    return .exact(CGSize(width: chatLayout.layoutFrame.width, height: measured.totalHeight))
                }
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 200))

            case .placeholder:
                return .exact(CGSize(width: chatLayout.layoutFrame.width, height: 500))
            }
        }

        func alignmentForItem(_ chatLayout: CollectionViewChatLayout, of kind: ItemKind, at indexPath: IndexPath) -> ChatItemAlignment {
            .fullWidth
        }

        func initialLayoutAttributesForInsertedItem(_ chatLayout: CollectionViewChatLayout, of kind: ItemKind, at indexPath: IndexPath, modifying originalAttributes: ChatLayoutAttributes, on state: InitialAttributesRequestType) {
            originalAttributes.alpha = 1
        }

        func finalLayoutAttributesForDeletedItem(_ chatLayout: CollectionViewChatLayout, of kind: ItemKind, at indexPath: IndexPath, modifying originalAttributes: ChatLayoutAttributes) {
            originalAttributes.alpha = 1
        }

        // MARK: - UICollectionViewDelegate

        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            cell.layer.removeAllAnimations()
            cell.contentView.layer.removeAllAnimations()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let containerHeight = scrollView.bounds.height

            // Trigger progressive loading when within 500pt of edges
            let loadThreshold: CGFloat = 500

            let now = CACurrentMediaTime()

            // Near top — load older (with cooldown)
            if offset < loadThreshold, canLoadOlder, !isLoadingOlder,
               now - lastLoadOlderTime >= loadCooldown {
                lastLoadOlderTime = now
                onLoadOlder?()
            }

            // Near bottom — load newer (with cooldown)
            let distanceFromBottom = contentHeight - offset - containerHeight
            if distanceFromBottom < loadThreshold, canLoadNewer, !isLoadingNewer,
               now - lastLoadNewerTime >= loadCooldown {
                lastLoadNewerTime = now
                onLoadNewer?()
            }

            DispatchQueue.main.async { [weak self] in
                self?.onScrollChange?(offset, contentHeight, containerHeight)
            }
        }
    }
}
#endif
