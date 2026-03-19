import Foundation
import os.log

extension Notification.Name {
    static let topicWasRead = Notification.Name("topicWasRead")
    static let showReplyComposer = Notification.Name("showReplyComposer")
}

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "ReadTracker")

/// Tracks which posts are visible on screen and reports reading time to Discourse.
/// Mimics the Discourse frontend's ScreenTrack behavior: ticks every second,
/// flushes accumulated timings every 60 seconds or when the user navigates away.
@Observable
@MainActor
final class TopicReadTracker {
    private var topicId: Int = 0
    private var baseURL: String = ""
    private var apiClient: DiscourseAPIClient?

    private var visiblePostNumbers: Set<Int> = []
    private var allSeenPostNumbers: Set<Int> = []
    private var highestPostNumber: Int = 0
    private var timings: [Int: Int] = [:]  // post_number -> accumulated ms
    private var topicTime: Int = 0         // total ms spent on this topic
    private var timer: Timer?
    private var hasNotifiedRead = false

    private static let tickInterval: TimeInterval = 1.0
    private static let flushThresholdMs = 5_000

    func start(topicId: Int, baseURL: String, apiClient: DiscourseAPIClient, highestPostNumber: Int) {
        // Flush any accumulated data from the previous topic
        flush()

        self.topicId = topicId
        self.baseURL = baseURL
        self.apiClient = apiClient
        self.highestPostNumber = highestPostNumber
        visiblePostNumbers = []
        allSeenPostNumbers = []
        timings = [:]
        topicTime = 0
        hasNotifiedRead = false

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        flush()
    }

    func postAppeared(_ postNumber: Int) {
        visiblePostNumbers.insert(postNumber)
        allSeenPostNumbers.insert(postNumber)
    }

    func postDisappeared(_ postNumber: Int) {
        visiblePostNumbers.remove(postNumber)
    }

    private func tick() {
        guard !visiblePostNumbers.isEmpty else { return }

        let ms = Int(Self.tickInterval * 1000)
        topicTime += ms
        for postNumber in visiblePostNumbers {
            timings[postNumber, default: 0] += ms
        }

        if topicTime >= Self.flushThresholdMs {
            flush()
        }
    }

    private func flush() {
        guard !timings.isEmpty, let apiClient else { return }

        let payload = timings
        let time = topicTime
        let tid = topicId
        let base = baseURL
        let hasSeenLastPost = highestPostNumber > 0 && allSeenPostNumbers.contains(highestPostNumber)
        let shouldNotify = !hasNotifiedRead && hasSeenLastPost
        if shouldNotify { hasNotifiedRead = true }

        // Reset accumulators
        timings = [:]
        topicTime = 0

        Task {
            do {
                try await apiClient.postTimings(
                    baseURL: base,
                    topicId: tid,
                    topicTime: time,
                    timings: payload
                )
                log.debug("Flushed timings for topic \(tid): \(payload.count) posts, \(time)ms total")

                if shouldNotify {
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .topicWasRead,
                            object: nil,
                            userInfo: ["topicId": tid]
                        )
                    }
                }
            } catch {
                log.warning("Failed to post timings: \(error.localizedDescription)")
            }
        }
    }
}
