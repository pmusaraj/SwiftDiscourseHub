#if os(iOS)
import UIKit
import SwiftUI
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "CollectionView")

/// UICollectionView wrapper that handles bidirectional post loading with
/// Signal-style content offset adjustment when prepending items.
struct PostStreamCollectionView: UIViewRepresentable {

    // MARK: - Data

    let items: [StreamItem]
    let postMarkdown: [Int: String]
    let avatarLookup: [String: String]
    let baseURL: String
    let contentWidth: CGFloat
    let topicId: Int
    let likedPostIds: Set<Int>
    let isAuthenticated: Bool
    let isLoadingOlder: Bool
    let isLoadingNewer: Bool

    // MARK: - Scroll request (set externally, consumed once)

    var scrollToPostId: Int?
    var scrollAnchor: UICollectionView.ScrollPosition = .centeredVertically

    // MARK: - Callbacks

    var onLike: ((Post) async -> Void)?
    var onQuote: ((String, Post) -> Void)?
    var onScrollToPost: ((Int) -> Void)?
    var onPostAppeared: ((Post) -> Void)?
    var onPostDisappeared: ((Post) -> Void)?
    var onScrollChange: ((_ offset: CGFloat, _ contentHeight: CGFloat, _ containerHeight: CGFloat) -> Void)?
    var onScrollDidComplete: (() -> Void)?

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(150)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 0
            return section
        }

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.delegate = context.coordinator
        cv.contentInset.bottom = 100
        cv.scrollIndicatorInsets = .zero
        cv.showsVerticalScrollIndicator = false

        // Cell registration — captures coordinator weakly for rendering
        let registration = UICollectionView.CellRegistration<UICollectionViewCell, StreamItem> {
            [weak coordinator = context.coordinator] cell, _, item in
            guard let coordinator else { return }
            cell.contentConfiguration = UIHostingConfiguration {
                coordinator.cellContent(for: item)
                    .transaction { $0.animation = nil }
            }
            .margins(.all, 0)
        }

        // Diffable data source
        let diffDS = UICollectionViewDiffableDataSource<Int, String>(collectionView: cv) {
            [weak coordinator = context.coordinator] cv, indexPath, itemId in
            guard let coordinator, let item = coordinator.itemsById[itemId] else { return nil }
            return cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }

        context.coordinator.diffableDataSource = diffDS
        context.coordinator.collectionView = cv
        context.coordinator.updateFrom(self)

        // Apply initial snapshot
        applySnapshot(coordinator: context.coordinator, isPrepend: false)

        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        let oldItemIds = coordinator.currentItemIds
        let newItemIds = items.map(\.id)
        let structureChanged = oldItemIds != newItemIds

        coordinator.updateFrom(self)

        UIView.performWithoutAnimation {
            if structureChanged {
                // Detect prepend: first item changed and old items are still present
                let isPrepend: Bool = {
                    guard let oldFirst = oldItemIds.first,
                          let newFirst = newItemIds.first,
                          oldFirst != newFirst else { return false }
                    return newItemIds.contains(oldFirst)
                }()

                if isPrepend {
                    log.info("[cv] prepend detected, adjusting offset")
                    let heightBefore = cv.contentSize.height

                    applySnapshot(coordinator: coordinator, isPrepend: true)
                    cv.layoutIfNeeded()

                    let heightAfter = cv.contentSize.height
                    let delta = heightAfter - heightBefore
                    if delta > 0 {
                        cv.contentOffset.y += delta
                        log.info("[cv] offset adjusted by \(delta)pt (before=\(heightBefore), after=\(heightAfter))")
                    }
                } else {
                    applySnapshot(coordinator: coordinator, isPrepend: false)
                }

                coordinator.currentItemIds = newItemIds
            } else {
                // Structure unchanged — reconfigure visible cells for data updates (markdown loaded, likes, etc.)
                reconfigureVisibleCells(coordinator: coordinator)
            }
        }

        // Handle scroll-to request
        if let targetId = scrollToPostId, targetId != coordinator.lastScrolledToId {
            let targetItemId = "post-\(targetId)"
            if let idx = items.firstIndex(where: { $0.id == targetItemId }) {
                cv.scrollToItem(
                    at: IndexPath(item: idx, section: 0),
                    at: scrollAnchor,
                    animated: true
                )
                coordinator.lastScrolledToId = targetId
                log.info("[cv] scrolled to post \(targetId) at index \(idx)")
            }
        }
    }

    // MARK: - Snapshot Management

    private func applySnapshot(coordinator: Coordinator, isPrepend: Bool) {
        coordinator.itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(items.map(\.id))
        coordinator.diffableDataSource?.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigureVisibleCells(coordinator: Coordinator) {
        coordinator.itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        guard var snapshot = coordinator.diffableDataSource?.snapshot() else { return }
        guard let cv = coordinator.collectionView else { return }

        let visibleIds = cv.indexPathsForVisibleItems.compactMap {
            coordinator.diffableDataSource?.itemIdentifier(for: $0)
        }
        guard !visibleIds.isEmpty else { return }
        snapshot.reconfigureItems(visibleIds)
        coordinator.diffableDataSource?.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICollectionViewDelegate {
        var diffableDataSource: UICollectionViewDiffableDataSource<Int, String>?
        weak var collectionView: UICollectionView?

        var itemsById: [String: StreamItem] = [:]
        var currentItemIds: [String] = []
        var lastScrolledToId: Int?

        // Cell rendering data (updated each cycle)
        var postMarkdown: [Int: String] = [:]
        var avatarLookup: [String: String] = [:]
        var baseURL: String = ""
        var contentWidth: CGFloat = 0
        var topicId: Int = 0
        var likedPostIds: Set<Int> = []
        var isAuthenticated: Bool = false

        // Callbacks
        var onLike: ((Post) async -> Void)?
        var onQuote: ((String, Post) -> Void)?
        var onScrollToPost: ((Int) -> Void)?
        var onPostAppeared: ((Post) -> Void)?
        var onPostDisappeared: ((Post) -> Void)?
        var onScrollChange: ((_ offset: CGFloat, _ contentHeight: CGFloat, _ containerHeight: CGFloat) -> Void)?

        func updateFrom(_ parent: PostStreamCollectionView) {
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
            onPostAppeared = parent.onPostAppeared
            onPostDisappeared = parent.onPostDisappeared
            onScrollChange = parent.onScrollChange
        }

        // MARK: - Cell Content

        @ViewBuilder
        func cellContent(for item: StreamItem) -> some View {
            switch item {
            case .post(let post):
                VStack(alignment: .leading, spacing: 0) {
                    if post.isSmallAction {
                        SmallActionView(post: post)
                            .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
                    } else {
                        PostView(
                            post: post,
                            baseURL: baseURL,
                            markdown: postMarkdown[post.postNumber ?? 0],
                            contentWidth: contentWidth,
                            isLiked: likedPostIds.contains(post.id) || post.hasLiked,
                            isWhisper: post.isWhisper,
                            currentTopicId: topicId,
                            avatarLookup: avatarLookup,
                            onLike: post.canLike && isAuthenticated ? { [weak self] in
                                await self?.onLike?(post)
                            } : nil,
                            onQuote: { [weak self] text in
                                self?.onQuote?(text, post)
                            },
                            onScrollToPost: { [weak self] pn in
                                self?.onScrollToPost?(pn)
                            }
                        )
                    }
                    Divider()
                }

            case .placeholder(_, let count):
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                        Text("^[\(count) earlier post](inflect: true)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.placeholderVertical)
                    .background(Color.blue.opacity(0.07))
                    Divider()
                }
            }
        }

        // MARK: - UICollectionViewDelegate

        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let itemId = diffableDataSource?.itemIdentifier(for: indexPath),
                  let item = itemsById[itemId] else { return }
            if case .post(let post) = item {
                onPostAppeared?(post)
            }
        }

        func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            // Use itemId lookup — indexPath may be stale after snapshot changes
            guard let itemId = diffableDataSource?.itemIdentifier(for: indexPath),
                  let item = itemsById[itemId] else { return }
            if case .post(let post) = item {
                onPostDisappeared?(post)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let containerHeight = scrollView.bounds.height
            onScrollChange?(offset, contentHeight, containerHeight)
        }
    }
}
#endif
