#if os(iOS)
import Testing
import Foundation
import UIKit
import SwiftUI

@testable import SwiftDiscourseHub

@MainActor struct PostStreamLayoutTests {

    // MARK: - Height Measurement

    @Test func measureSimpleTextView() {
        let width: CGFloat = 375
        let content = VStack(alignment: .leading, spacing: 0) {
            Text("Hello, this is a test post with some content that should wrap to multiple lines when displayed at a reasonable width.")
                .padding()
            Divider()
        }

        let height = measureHeight(of: content, width: width)
        #expect(height > 30, "Simple text should have height > 30, got \(height)")
        #expect(height < 300, "Simple text should have height < 300, got \(height)")
    }

    @Test func measureTallContent() {
        let width: CGFloat = 375
        let content = VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<10, id: \.self) { i in
                Text("Line \(i): Some content that contributes to the overall height of this view.")
                    .padding(.vertical, 8)
            }
            Divider()
        }

        let height = measureHeight(of: content, width: width)
        #expect(height > 200, "Tall content should have height > 200, got \(height)")
    }

    @Test func measureDifferentItemsGetDifferentHeights() {
        let width: CGFloat = 375
        let short = VStack {
            Text("Short")
                .padding()
            Divider()
        }
        let tall = VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<20, id: \.self) { i in
                Text("Line \(i)")
                    .padding(.vertical, 4)
            }
            Divider()
        }

        let shortHeight = measureHeight(of: short, width: width)
        let tallHeight = measureHeight(of: tall, width: width)
        #expect(tallHeight > shortHeight, "Tall (\(tallHeight)) should be > short (\(shortHeight))")
    }

    @Test func measureWidthAffectsHeight() {
        let content = VStack(alignment: .leading, spacing: 0) {
            Text("This is a longer piece of text that will definitely need to wrap across multiple lines when the available width is narrow, but might fit in fewer lines when the width is wider.")
                .padding()
            Divider()
        }

        let narrowHeight = measureHeight(of: content, width: 200)
        let wideHeight = measureHeight(of: content, width: 600)
        #expect(narrowHeight > wideHeight, "Narrow (\(narrowHeight)) should be taller than wide (\(wideHeight))")
    }

    // MARK: - Compare measurement approaches

    @Test func compareSizeThatFitsVsSystemLayout() {
        let width: CGFloat = 375
        let content = VStack(alignment: .leading, spacing: 0) {
            Text("A test paragraph with enough text to wrap. This needs to be reasonably long to exercise the width constraint properly.")
                .padding()
            Divider()
        }

        // Approach A: sizeThatFits with greatestFiniteMagnitude
        let hcA = UIHostingController(rootView: content)
        let sizeA = hcA.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))

        // Approach B: systemLayoutSizeFitting with width constraint
        let hcB = UIHostingController(rootView: content)
        hcB.view.translatesAutoresizingMaskIntoConstraints = false
        hcB.view.widthAnchor.constraint(equalToConstant: width).isActive = true
        hcB.view.setNeedsLayout()
        hcB.view.layoutIfNeeded()
        let sizeB = hcB.view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        // Approach C: sizeThatFits with layoutFittingCompressedSize (height=0)
        let hcC = UIHostingController(rootView: content)
        let sizeC = hcC.sizeThatFits(in: CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))

        // Log all three
        print("Approach A (sizeThatFits, h=inf):     \(sizeA.height)")
        print("Approach B (systemLayout, constraint): \(sizeB.height)")
        print("Approach C (sizeThatFits, h=0):        \(sizeC.height)")

        // At least A should give a reasonable height
        #expect(sizeA.height > 30, "sizeThatFits(h=inf) should work, got \(sizeA.height)")
        #expect(sizeA.width <= width + 1, "Width should not exceed constraint, got \(sizeA.width)")
    }

    // MARK: - Layout Computation

    @Test func layoutOffsetsAreCumulative() {
        let heights: [String: CGFloat] = ["a": 100, "b": 200, "c": 150]
        let ids = ["a", "b", "c"]

        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for id in ids {
            offsets.append(y)
            y += heights[id] ?? 0
        }

        #expect(offsets == [0, 100, 300])
        #expect(y == 450)
    }

    @Test func layoutNoOverlap() {
        let heights: [String: CGFloat] = ["a": 100, "b": 250, "c": 75, "d": 300]
        let ids = ["a", "b", "c", "d"]

        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for id in ids {
            offsets.append(y)
            y += heights[id] ?? 0
        }

        for i in 1..<ids.count {
            let prevBottom = offsets[i - 1] + heights[ids[i - 1]]!
            let currentTop = offsets[i]
            #expect(prevBottom == currentTop, "Item \(ids[i]) top (\(currentTop)) should equal item \(ids[i-1]) bottom (\(prevBottom))")
        }
    }

    // MARK: - End-to-end: measure then layout

    @Test func endToEndMeasureAndLayout() {
        let width: CGFloat = 375

        // Simulate 5 posts with varying content
        let views: [(String, AnyView)] = [
            ("post-1", AnyView(VStack { Text("Short post").padding(); Divider() })),
            ("post-2", AnyView(VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<5, id: \.self) { i in Text("Line \(i) of medium post").padding(.vertical, 4) }
                Divider()
            })),
            ("post-3", AnyView(VStack { Text("Another short one").padding(); Divider() })),
            ("post-4", AnyView(VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<15, id: \.self) { i in Text("Line \(i) of a very long post with lots of text").padding(.vertical, 4) }
                Divider()
            })),
            ("post-5", AnyView(VStack { Text("Final").padding(); Divider() })),
        ]

        // Step 1: Measure all
        var heights: [String: CGFloat] = [:]
        for (id, view) in views {
            let hc = UIHostingController(rootView: view)
            let size = hc.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            heights[id] = max(size.height, 44)
        }

        // Step 2: Compute layout
        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for (id, _) in views {
            offsets.append(y)
            y += heights[id]!
        }
        let totalHeight = y

        // Step 3: Verify no overlaps
        for i in 1..<views.count {
            let prevId = views[i - 1].0
            let prevBottom = offsets[i - 1] + heights[prevId]!
            let currentTop = offsets[i]
            #expect(abs(prevBottom - currentTop) < 0.001,
                    "Item \(i) top (\(currentTop)) != prev bottom (\(prevBottom))")
        }

        // Step 4: Verify total height is sum of all heights
        let sumOfHeights = heights.values.reduce(0, +)
        #expect(abs(totalHeight - sumOfHeights) < 0.001,
                "Total height (\(totalHeight)) != sum (\(sumOfHeights))")

        // Step 5: Verify all heights are positive and reasonable
        for (id, h) in heights {
            #expect(h > 0, "\(id) has zero/negative height: \(h)")
            print("\(id): height=\(h), offset=\(offsets[views.firstIndex(where: { $0.0 == id })!])")
        }
        print("Total height: \(totalHeight)")
    }

    // MARK: - Diagnostic: sizeThatFits vs actual rendered size

    @Test func sizeThatFitsMatchesRenderedSize() {
        let width: CGFloat = 375
        let content = VStack(alignment: .leading, spacing: 0) {
            Text("A post with enough text to wrap at 375pt. This simulates what a real post cell might look like with content.")
                .padding()
            Divider()
        }

        // Approach: sizeThatFits
        let hc1 = UIHostingController(rootView: content)
        let measured = hc1.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))

        // Approach: set frame, layout, then check intrinsicContentSize
        let hc2 = UIHostingController(rootView: content)
        hc2.view.frame = CGRect(x: 0, y: 0, width: width, height: 10000)
        hc2.view.setNeedsLayout()
        hc2.view.layoutIfNeeded()
        let intrinsic = hc2.view.intrinsicContentSize

        // Approach: set frame, layout, sizeThatFits on the VIEW (not controller)
        let hc3 = UIHostingController(rootView: content)
        hc3.view.frame = CGRect(x: 0, y: 0, width: width, height: 10000)
        hc3.view.setNeedsLayout()
        hc3.view.layoutIfNeeded()
        let viewSize = hc3.view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

        print("sizeThatFits(controller): \(measured.height)")
        print("intrinsicContentSize:     \(intrinsic.height)")
        print("view.sizeThatFits:        \(viewSize.height)")

        #expect(measured.height > 0)
        #expect(intrinsic.height > 0)

        // Check if they agree (within 1pt tolerance)
        let diff = abs(measured.height - intrinsic.height)
        print("Difference (sizeThatFits vs intrinsic): \(diff)")
    }

    @Test func sizeThatFitsWithFrameModifier() {
        // Test whether adding .frame(width:) to the content changes the measurement
        let width: CGFloat = 375
        let bare = VStack(alignment: .leading, spacing: 0) {
            Text("Text that wraps. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again.")
                .padding()
            Divider()
        }
        let framed = VStack(alignment: .leading, spacing: 0) {
            Text("Text that wraps. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again.")
                .padding()
            Divider()
        }
        .frame(width: width, alignment: .leading)

        let hcBare = UIHostingController(rootView: bare)
        let bareMeasured = hcBare.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))

        let hcFramed = UIHostingController(rootView: framed)
        let framedMeasured = hcFramed.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))

        print("Bare:   \(bareMeasured.height)")
        print("Framed: \(framedMeasured.height)")

        let diff = abs(bareMeasured.height - framedMeasured.height)
        print("Difference: \(diff)")
    }

    // MARK: - Rich content measurement

    @Test func measurePostLikeLayout() {
        // Simulates a real PostView: avatar header + body text + footer
        let width: CGFloat = 393 // iPhone 15 Pro width
        let content = VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name + date
            HStack(spacing: 8) {
                Circle().fill(.gray).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Username").font(.headline)
                    Text("@username").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("2h ago").font(.caption).foregroundStyle(.secondary)
            }
            Spacer().frame(height: 8)
            // Body: multi-paragraph text
            VStack(alignment: .leading, spacing: 8) {
                Text("This is the first paragraph of a forum post. It contains enough text to wrap across multiple lines at typical phone widths.")
                Text("And here's a second paragraph with some more detail. Posts on Discourse often have multiple paragraphs with detailed discussion.")
            }
            .font(.body)
            Spacer().frame(height: 8)
            // Footer: like button + reply count
            HStack {
                Label("3", systemImage: "heart").font(.caption)
                Spacer()
                Label("2 replies", systemImage: "bubble.left").font(.caption)
            }
            .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.horizontal, 16)

        let height = measureHeight(of: content, width: width)
        print("Post-like layout height: \(height)")
        #expect(height > 100, "Post layout should be > 100pt, got \(height)")
        #expect(height < 500, "Post layout should be < 500pt, got \(height)")
    }

    @Test func measurePostWithInlineImage() {
        let width: CGFloat = 393
        let content = VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle().fill(.gray).frame(width: 40, height: 40)
                Text("Poster").font(.headline)
                Spacer()
            }
            Spacer().frame(height: 8)
            // Body with text and inline image placeholder
            VStack(alignment: .leading, spacing: 8) {
                Text("Here's a screenshot of the issue:")
                // Simulates a pre-sized image (like DiscourseImageAttachmentLoader)
                Color.gray.opacity(0.3)
                    .frame(width: min(width - 32, 600), height: 300)
                    .cornerRadius(8)
                Text("As you can see in the image above, the layout is broken.")
            }
            .font(.body)
            Spacer().frame(height: 8)
            Divider()
        }
        .padding(.horizontal, 16)

        let height = measureHeight(of: content, width: width)
        print("Post with image height: \(height)")
        #expect(height > 400, "Post with 300pt image should be > 400pt, got \(height)")
    }

    @Test func measurePostWithQuoteBlock() {
        let width: CGFloat = 393
        let content = VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle().fill(.gray).frame(width: 40, height: 40)
                Text("Replier").font(.headline)
                Spacer()
            }
            Spacer().frame(height: 8)
            // Quote block (simulates QuoteBlockView)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle().fill(.gray).frame(width: 20, height: 20)
                    Text("OriginalPoster:").font(.caption).bold()
                }
                Text("This is the quoted text from another post. It can be quite long and wraps across multiple lines. The quote block has a distinctive visual style.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)
            // Reply text
            Text("I agree with this point. Here is my longer response that also wraps across several lines to simulate real forum content.")
                .font(.body)
                .padding(.horizontal, 16)
            Spacer().frame(height: 8)
            Divider()
        }

        let height = measureHeight(of: content, width: width)
        print("Post with quote height: \(height)")
        #expect(height > 150, "Post with quote should be > 150pt, got \(height)")
    }

    @Test func measurePostWithMultipleImagesAndText() {
        let width: CGFloat = 393
        let content = VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(.gray).frame(width: 40, height: 40)
                Text("PhotoPoster").font(.headline)
                Spacer()
            }
            Spacer().frame(height: 8)
            VStack(alignment: .leading, spacing: 8) {
                Text("Check out these screenshots from the new release:")
                Color.gray.opacity(0.3).frame(height: 250).cornerRadius(8)
                Text("And here's the settings panel:")
                Color.gray.opacity(0.3).frame(height: 200).cornerRadius(8)
                Text("Finally, the results dashboard:")
                Color.gray.opacity(0.3).frame(height: 350).cornerRadius(8)
                Text("Let me know what you think of the new design!")
            }
            .font(.body)
            Spacer().frame(height: 8)
            HStack {
                Label("12", systemImage: "heart").font(.caption)
                Spacer()
                Label("5 replies", systemImage: "bubble.left").font(.caption)
            }
            .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.horizontal, 16)

        let height = measureHeight(of: content, width: width)
        print("Post with multiple images height: \(height)")
        #expect(height > 900, "Multi-image post should be > 900pt, got \(height)")
    }

    @Test func measureMixedPostsNoOverlap() {
        // End-to-end: measure several different post types, compute layout, verify no overlap
        let width: CGFloat = 393

        let posts: [(String, AnyView)] = [
            ("post-1", AnyView(makePostView(width: width, body: "Short reply.", hasImage: false, hasQuote: false))),
            ("post-2", AnyView(makePostView(width: width, body: "A post with a long discussion about architecture decisions. This goes on for multiple lines to simulate real content. The author is very thorough in their explanation and covers many different aspects of the problem.", hasImage: false, hasQuote: false))),
            ("post-3", AnyView(makePostView(width: width, body: "Here's a screenshot:", hasImage: true, hasQuote: false))),
            ("post-4", AnyView(makePostView(width: width, body: "I agree!", hasImage: false, hasQuote: true))),
            ("post-5", AnyView(makePostView(width: width, body: "Check these out:", hasImage: true, hasQuote: true))),
        ]

        // Measure all
        var heights: [String: CGFloat] = [:]
        for (id, view) in posts {
            let hc = UIHostingController(rootView: view)
            let size = hc.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            heights[id] = max(size.height, 44)
            print("\(id): \(heights[id]!)pt")
        }

        // Compute layout
        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for (id, _) in posts {
            offsets.append(y)
            y += heights[id]!
        }

        // Verify no overlaps and all heights > 0
        for i in 1..<posts.count {
            let prevId = posts[i - 1].0
            let prevBottom = offsets[i - 1] + heights[prevId]!
            let currentTop = offsets[i]
            #expect(abs(prevBottom - currentTop) < 0.001,
                    "Item \(posts[i].0) top (\(currentTop)) != prev bottom (\(prevBottom))")
        }

        for (id, h) in heights {
            #expect(h >= 44, "\(id) height too small: \(h)")
        }

        // Post with image should be taller than text-only
        #expect(heights["post-3"]! > heights["post-1"]!, "Image post should be taller than short text post")
        print("Total height: \(y)")
    }

    // Helper to build a post-like view
    private func makePostView(width: CGFloat, body: String, hasImage: Bool, hasQuote: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle().fill(.gray).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("User").font(.headline)
                    Text("@user").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("1h").font(.caption).foregroundStyle(.secondary)
            }
            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 8) {
                if hasQuote {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OriginalPoster:").font(.caption).bold()
                        Text("Previously quoted text that provides context for the reply.")
                            .font(.body).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                Text(body).font(.body)
                if hasImage {
                    Color.gray.opacity(0.3)
                        .frame(width: min(width - 32, 600), height: 280)
                        .cornerRadius(8)
                }
            }
            Spacer().frame(height: 8)
            HStack {
                Label("1", systemImage: "heart").font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Rendered frame verification

    @Test func renderedFramesDoNotOverlap() {
        let width: CGFloat = 393

        // Build views of varying height
        let items: [(String, AnyView)] = [
            ("a", AnyView(makePostView(width: width, body: "Short.", hasImage: false, hasQuote: false))),
            ("b", AnyView(makePostView(width: width, body: "A longer post with multiple lines of text to make it taller than the short one.", hasImage: false, hasQuote: false))),
            ("c", AnyView(makePostView(width: width, body: "Image post:", hasImage: true, hasQuote: false))),
            ("d", AnyView(makePostView(width: width, body: "Quote reply.", hasImage: false, hasQuote: true))),
        ]

        // Step 1: Measure heights (same as production code)
        var heights: [String: CGFloat] = [:]
        for (id, view) in items {
            let hc = UIHostingController(rootView: view)
            let size = hc.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            heights[id] = max(size.height, 44)
        }

        // Step 2: Compute layout offsets
        var offsets: [CGFloat] = []
        var y: CGFloat = 0
        for (id, _) in items {
            offsets.append(y)
            y += heights[id]!
        }
        let totalHeight = y

        // Step 3: Build actual UIScrollView + contentView + hosting controllers with constraints
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: width, height: 800))
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: totalHeight))
        scrollView.addSubview(contentView)
        scrollView.contentSize = CGSize(width: width, height: totalHeight)

        var hostControllers: [(String, UIHostingController<AnyView>)] = []
        for (i, (id, view)) in items.enumerated() {
            let hc = UIHostingController(rootView: view)
            let v = hc.view!
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)

            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                v.widthAnchor.constraint(equalToConstant: width),
                v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: offsets[i]),
                v.heightAnchor.constraint(equalToConstant: heights[id]!),
            ])
            hostControllers.append((id, hc))
        }

        // Step 4: Force layout
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()

        // Step 5: Read actual rendered frames and verify
        print("--- Rendered frames ---")
        var renderedFrames: [(String, CGRect)] = []
        for (id, hc) in hostControllers {
            let frame = hc.view.frame
            print("\(id): frame=\(frame), expected y=\(offsets[items.firstIndex(where: { $0.0 == id })!]), expected h=\(heights[id]!)")
            renderedFrames.append((id, frame))
        }

        // Verify frames match expected positions
        for (i, (id, frame)) in renderedFrames.enumerated() {
            let expectedY = offsets[i]
            let expectedH = heights[id]!
            #expect(abs(frame.origin.y - expectedY) < 1.0,
                    "\(id): rendered y (\(frame.origin.y)) != expected (\(expectedY))")
            #expect(abs(frame.size.height - expectedH) < 1.0,
                    "\(id): rendered height (\(frame.size.height)) != expected (\(expectedH))")
            #expect(abs(frame.size.width - width) < 1.0,
                    "\(id): rendered width (\(frame.size.width)) != expected (\(width))")
        }

        // Verify no overlap: each item's top >= previous item's bottom
        for i in 1..<renderedFrames.count {
            let prevBottom = renderedFrames[i - 1].1.maxY
            let currentTop = renderedFrames[i].1.minY
            #expect(currentTop >= prevBottom - 1.0,
                    "Overlap: \(renderedFrames[i].0) top (\(currentTop)) < \(renderedFrames[i - 1].0) bottom (\(prevBottom))")
        }
    }

    @Test func recycledHostControllerConstraints() {
        // Simulate the pool recycling flow from the production code
        let width: CGFloat = 393
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 2000))
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: width, height: 800))
        scrollView.addSubview(contentView)

        // First use: add a hosting controller at y=0, h=200
        let hc = UIHostingController(rootView: AnyView(Text("First content").padding()))
        let v = hc.view!
        v.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(v)

        let top1 = v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0)
        let h1 = v.heightAnchor.constraint(equalToConstant: 200)
        let w1 = v.widthAnchor.constraint(equalToConstant: width)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            w1, top1, h1,
        ])
        contentView.layoutIfNeeded()

        print("First use frame: \(v.frame)")
        #expect(abs(v.frame.origin.y - 0) < 1, "First use y should be 0")
        #expect(abs(v.frame.height - 200) < 1, "First use height should be 200")

        // Simulate removal (like pool recycling)
        v.removeFromSuperview()
        hc.rootView = AnyView(EmptyView())

        // Check what constraints remain on the view after removal
        print("Constraints after removal: \(v.constraints.count)")
        for c in v.constraints {
            print("  \(c)")
        }

        // Second use: clear stale constraints, re-add at y=500, h=300
        hc.rootView = AnyView(Text("Second content, longer").padding())
        v.removeConstraints(v.constraints)
        v.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(v)

        let top2 = v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 500)
        let h2 = v.heightAnchor.constraint(equalToConstant: 300)
        let w2 = v.widthAnchor.constraint(equalToConstant: width)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            w2, top2, h2,
        ])
        contentView.layoutIfNeeded()

        print("Second use frame: \(v.frame)")
        print("All constraints on view after re-add: \(v.constraints.count)")
        for c in v.constraints {
            print("  \(c)")
        }

        #expect(abs(v.frame.origin.y - 500) < 1, "Second use y should be 500, got \(v.frame.origin.y)")
        #expect(abs(v.frame.height - 300) < 1, "Second use height should be 300, got \(v.frame.height)")
    }

    // MARK: - Measurement helper

    private func measureHeight<V: View>(of view: V, width: CGFloat) -> CGFloat {
        let hc = UIHostingController(rootView: view)
        let size = hc.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        return size.height
    }
}
#endif
