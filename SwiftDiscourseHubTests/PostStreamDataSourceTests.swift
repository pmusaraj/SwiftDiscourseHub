import Testing
import Foundation
import UIKit
import SwiftUI

@testable import SwiftDiscourseHub

// MARK: - Test Helpers

private func makePost(id: Int, postNumber: Int) -> Post {
    let json = """
    {
        "id": \(id),
        "post_number": \(postNumber),
        "username": "user\(id)",
        "name": "User \(id)",
        "cooked": "<p>Post \(postNumber) content</p>",
        "created_at": "2024-01-01T00:00:00.000Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try! decoder.decode(Post.self, from: json.data(using: .utf8)!)
}

private func makeStream(count: Int) -> [Int] {
    Array(1...count)
}

private func makePosts(ids: [Int]) -> [Post] {
    ids.map { makePost(id: $0, postNumber: $0) }
}

// MARK: - Tests

@MainActor @Suite(.serialized) struct PostStreamDataSourceTests {

    // MARK: - Window State After Initial Load

    @Test func initialLoadSetsWindow() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        #expect(ds.canLoadOlder == false)
        #expect(ds.canLoadNewer == true)
        #expect(ds.items.count == 20)
        #expect(ds.loadedPostIds.count == 20)
    }

    @Test func initialLoadAtEndSetsCorrectFlags() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let posts = makePosts(ids: Array(stream[30..<50]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 30, windowEnd: 50)

        #expect(ds.canLoadOlder == true)
        #expect(ds.canLoadNewer == false)
    }

    @Test func initialLoadWithFullStream() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 10)
        let posts = makePosts(ids: stream)
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 10)

        #expect(ds.canLoadOlder == false)
        #expect(ds.canLoadNewer == false)
        #expect(ds.items.count == 10)
    }

    // MARK: - canLoadNewer / canLoadOlder

    @Test func canLoadNewerWhenWindowEndLessThanStreamCount() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let posts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)
        #expect(ds.canLoadNewer == true)
    }

    @Test func cannotLoadNewerWhenAtEnd() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 20)
        let posts = makePosts(ids: stream)
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)
        #expect(ds.canLoadNewer == false)
    }

    @Test func canLoadOlderWhenWindowStartGreaterThanZero() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let posts = makePosts(ids: Array(stream[40..<60]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 40, windowEnd: 60)
        #expect(ds.canLoadOlder == true)
    }

    @Test func cannotLoadOlderWhenAtStart() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let posts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)
        #expect(ds.canLoadOlder == false)
    }

    @Test func windowInMiddleCanLoadBothDirections() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 200)
        let posts = makePosts(ids: Array(stream[80..<120]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 80, windowEnd: 120)

        #expect(ds.canLoadOlder == true)
        #expect(ds.canLoadNewer == true)
        #expect(ds.items.count == 40)
    }

    // MARK: - hasMore

    @Test func hasMoreWhenNotAllLoaded() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let posts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)
        #expect(ds.hasMore == true)
    }

    @Test func hasMoreFalseWhenAllLoaded() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 10)
        let posts = makePosts(ids: stream)
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 10)
        #expect(ds.hasMore == false)
    }

    // MARK: - postCount

    @Test func postCountMatchesItemCount() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let posts = makePosts(ids: Array(stream[0..<15]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 15)
        #expect(ds.postCount == 15)
    }

    // MARK: - Item ordering

    @Test func itemsAreInCorrectOrder() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let posts = makePosts(ids: Array(stream[10..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 10, windowEnd: 20)

        let postNumbers = ds.items.compactMap {
            if case .post(let p) = $0 { return p.postNumber }
            return nil
        }
        #expect(postNumbers == Array(11...20))
    }

    // MARK: - Reset

    @Test func resetClearsEverything() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let posts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)

        ds.reset()

        #expect(ds.items.isEmpty)
        #expect(ds.stream.isEmpty)
        #expect(ds.loadedPostIds.isEmpty)
        #expect(ds.canLoadOlder == false)
        #expect(ds.canLoadNewer == false)
    }

    // MARK: - Edge Cases

    @Test func emptyStreamHasNoLoadCapability() {
        let ds = PostStreamDataSource()
        ds.configureForTesting(stream: [], posts: [], windowStart: 0, windowEnd: 0)

        #expect(ds.canLoadOlder == false)
        #expect(ds.canLoadNewer == false)
        #expect(ds.hasMore == false)
        #expect(ds.items.isEmpty)
    }

    @Test func singlePostStream() {
        let ds = PostStreamDataSource()
        let stream = [42]
        let posts = [makePost(id: 42, postNumber: 1)]
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 1)

        #expect(ds.canLoadOlder == false)
        #expect(ds.canLoadNewer == false)
        #expect(ds.items.count == 1)
        #expect(ds.postCount == 1)
        #expect(ds.hasMore == false)
    }

    @Test func jumpToPostAlreadyInWindow() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let posts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 0, windowEnd: 20)

        let result = await ds.jumpToPost(number: 10)
        #expect(result == 10)
    }

    @Test func loadedPostIdsMatchesItems() {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let ids = Array(stream[20..<40])
        let posts = makePosts(ids: ids)
        ds.configureForTesting(stream: stream, posts: posts, windowStart: 20, windowEnd: 40)

        let itemIds = Set(ds.items.compactMap {
            if case .post(let p) = $0 { return p.id }
            return nil
        })
        #expect(ds.loadedPostIds == itemIds)
    }

    // MARK: - Jump to Post (replace window)

    @Test func jumpToLastPostReplacesWindow() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let result = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        #expect(result == 100, "Should return the last post's ID")
        #expect(ds.canLoadNewer == false, "Should be at the end of the stream")
        #expect(ds.canLoadOlder == true, "Should be able to load older")

        // Window replaced: only the 20 fetched posts
        #expect(ds.items.count == 20, "Expected 20 items, got \(ds.items.count)")
        #expect(ds.loadedPostIds.count == 20)

        // No placeholders
        let hasPlaceholder = ds.items.contains {
            if case .placeholder = $0 { return true }
            return false
        }
        #expect(!hasPlaceholder, "Should have no placeholders")
    }

    @Test func jumpToLastPostReturnsCorrectId() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 50)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let result = ds.simulateJumpToPost(
            number: 50,
            fetchedPosts: makePosts(ids: Array(stream[30..<50]))
        )

        #expect(result == 50)
    }

    @Test func jumpReplacesExistingItems() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        // Original posts should be gone — window is replaced
        let postNumbers = ds.items.compactMap {
            if case .post(let p) = $0 { return p.postNumber }
            return nil
        }
        #expect(postNumbers == Array(81...100), "Items should be only the jumped-to posts")
    }

    @Test func jumpUpdatesWindowBoundaries() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        #expect(ds.windowStart == 80)
        #expect(ds.windowEnd == 100)
    }

    @Test func jumpPreservesStream() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        #expect(ds.stream.count == 100)
        #expect(ds.stream == stream)
    }

    @Test func jumpToMiddleSetsBothDirectionFlags() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 200)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        #expect(ds.canLoadOlder == true)
        #expect(ds.canLoadNewer == true)
    }

    @Test func jumpLastItemIsTargetPost() async {
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 100)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 100,
            fetchedPosts: makePosts(ids: Array(stream[80..<100]))
        )

        // The last item should be the target post
        if case .post(let lastPost) = ds.items.last {
            #expect(lastPost.postNumber == 100)
        } else {
            #expect(Bool(false), "Last item should be a post")
        }
    }

    // MARK: - UICollectionView Scroll Integration

    /// Result type to keep the data source alive (UICollectionView doesn't retain it).
    private class CVTestHarness {
        let window: UIWindow
        let collectionView: UICollectionView
        let dataSource: UICollectionViewDiffableDataSource<Int, StreamItem>
        init(window: UIWindow, collectionView: UICollectionView, dataSource: UICollectionViewDiffableDataSource<Int, StreamItem>) {
            self.window = window
            self.collectionView = collectionView
            self.dataSource = dataSource
        }
        func tearDown() { window.isHidden = true }
    }

    /// Helper: creates a UICollectionView with 200pt-tall cells in a window.
    private func makeCollectionView(items: [StreamItem]) async -> CVTestHarness {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(200))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(200))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }

        let cv = UICollectionView(frame: window.bounds, collectionViewLayout: layout)
        cv.contentInset = .zero
        window.addSubview(cv)
        window.makeKeyAndVisible()

        let cellReg = UICollectionView.CellRegistration<UICollectionViewCell, StreamItem> {
            cell, _, item in
            var content = UIListContentConfiguration.cell()
            content.text = item.id
            cell.contentConfiguration = content
        }

        let diffDS = UICollectionViewDiffableDataSource<Int, StreamItem>(collectionView: cv) {
            collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: item)
        }

        var snap = NSDiffableDataSourceSnapshot<Int, StreamItem>()
        snap.appendSections([0])
        snap.appendItems(items)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        await diffDS.apply(snap, animatingDifferences: false)
        cv.layoutIfNeeded()
        CATransaction.commit()

        return CVTestHarness(window: window, collectionView: cv, dataSource: diffDS)
    }

    @Test func jumpToLastPostNeedsScroll() async {
        // After jump, items are replaced. Without scrolling, the last post is NOT visible
        // because 20 cells × 200pt = 4000pt total, only ~4 fit in 844pt viewport.
        let ds = PostStreamDataSource()
        let stream = makeStream(count: 120)
        let initialPosts = makePosts(ids: Array(stream[0..<20]))
        ds.configureForTesting(stream: stream, posts: initialPosts, windowStart: 0, windowEnd: 20)

        let _ = ds.simulateJumpToPost(
            number: 120,
            fetchedPosts: makePosts(ids: Array(stream[100..<120]))
        )

        let h = await makeCollectionView(items: ds.items)
        let cv = h.collectionView
        let lastIdx = IndexPath(item: ds.items.count - 1, section: 0)

        // Without scrolling, last item should NOT be visible (proves scroll is needed)
        let visiblePaths = cv.indexPathsForVisibleItems
        #expect(
            !visiblePaths.contains(lastIdx),
            "Without scroll, last post should NOT be visible (baseline). Visible: \(visiblePaths.map(\.item).sorted())"
        )

        h.tearDown()
    }

}
