# SwiftDiscourseHub

SwiftUI multiplatform Discourse forum reader (iOS 18+, macOS 15+, iPadOS). Single Xcode target.

## Build & Test

```bash
# macOS
xcodebuild -scheme SwiftDiscourseHub -destination 'platform=macOS' build

# iOS
xcodebuild -scheme SwiftDiscourseHub -destination 'generic/platform=iOS Simulator' build

# Tests (Swift Testing framework)
xcodebuild -scheme SwiftDiscourseHub -destination 'platform=macOS' test
```

Requires Xcode 26 / Swift 6.2. Strict concurrency is set to `minimal`.

## Architecture

- **@Observable** (Observation framework) — not ObservableObject
- **SwiftData** for persistence (`DiscourseSite` model)
- **Snake-case decoding** via `decoder.keyDecodingStrategy = .convertFromSnakeCase`
- Services are `actor`-based (`DiscourseAPIClient`, `SiteDiscoveryService`)
- ViewModels are `@Observable` classes

## Key Conventions

### Platform abstractions

Markdownosaur.swift defines module-level typealiases: `PlatformFont`, `PlatformColor`, `PlatformImage`, `PlatformFontTraits`. Use these instead of `UIFont`/`NSFont` directly in shared code. Platform-specific code uses `#if os(iOS)` / `#else`.

### Styling

**All post element styling goes in Theme.swift** — never hardcode font sizes, colors, spacing, opacity, or padding in view/rendering code. Key sections:

- `Theme.Markdown` — body font, line height, code block padding/opacity, heading scale
- `Theme.Quote` — blockquote bar, background, padding, line height
- `Theme.Whisper` — opacity, icon

### Post rendering

Two platform-specific rendering paths, both using the shared `Markdownosaur` engine:

- **iOS**: `PostCell` (pure UIKit `UICollectionViewCell`) + `ChatLayout` + `PostCellSizeCache` for pre-measured heights
- **macOS**: `PostView` wraps `MarkdownNSTextView` (`NSViewRepresentable` with `NSTextView`)

Both use `QuoteBarLayoutManager` (custom `NSLayoutManager`) for drawing blockquote and code block backgrounds.

### Xcode project

pbxproj uses short hex IDs: `A10001`–`A100xx` (build files), `B10001`–`B100xx` (file refs), `E10001`+ (groups), `S10001`+ (packages), `R10001`+ (products). When adding files, find the highest existing ID and increment.

### Previews

- `Previews.swift` — shared `PreviewData` enum + category/discover/sidebar/filter previews
- `TopicPreviews.swift` — topic row + topic view previews (iOS uses `PostCellPreview` UIKit wrapper, macOS uses `PostView`)

### Platform gotchas

- `.navigationBar` toolbar placement unavailable on macOS — guard with `#if os(iOS)`
- `.listRowSpacing` unavailable on macOS — guard with `#if os(iOS)`
- `NSTextContainer.size` (iOS) vs `.containerSize` (macOS)
- `UIGraphicsGetCurrentContext()` (iOS) vs `NSGraphicsContext.current?.cgContext` (macOS)
- `NSBezierPath` has no `.cgPath` — extension in Markdownosaur.swift provides it

## Dependencies (SPM)

- **swift-markdown** — CommonMark/GFM parser (AST + MarkupVisitor)
- **swift-crypto** — RSA key generation for User API Key auth
- **Nuke** + **NukeUI** — image loading/caching
- **ChatLayout** — iOS-only collection view layout for bidirectional post streaming, important for correct up/down scrolling and jumping to specific positions

## File Structure

```
Models/APIModels/     — TopicListResponse, CategoryListResponse, TopicDetailResponse, etc.
Models/               — DiscourseSite (SwiftData @Model)
Services/             — DiscourseAPIClient, RawTopicParser, Markdownosaur, AuthService, etc.
ViewModels/           — @Observable VMs (SiteList, TopicList, CategoryList, AddSite)
Views/Topics/         — TopicListView, TopicRowView, TopicDetailView, PostView, PostCell
Views/Common/         — Previews, TopicPreviews, CachedAsyncImage, RelativeTimeText
Views/Sidebar/        — SiteSidebarView, SiteIconView
Views/Auth/           — LoginRequiredView, AuthFooterBar
Views/Composer/       — ComposerView
Tests/                — Swift Testing (DiscoverTests, RawTopicParserTests, AuthTests, ComposerTests)
```
