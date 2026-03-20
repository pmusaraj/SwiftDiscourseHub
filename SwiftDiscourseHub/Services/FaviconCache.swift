import Foundation
import os

#if os(macOS)
import AppKit
private typealias PlatformImage = NSImage
#else
import UIKit
private typealias PlatformImage = UIImage
#endif

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SwiftDiscourseHub", category: "FaviconCache")

actor FaviconCache {
    static let shared = FaviconCache()

    private struct CacheEntry: Codable {
        let data: Data
        let date: Date
    }

    private let cacheDuration: TimeInterval = 7 * 24 * 60 * 60 // 1 week
    private var memory: [String: Data] = [:]

    private var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func favicon(for domain: String) async -> Data? {
        // Check memory
        if let data = memory[domain] {
            return data
        }

        // Check disk
        let fileURL = cacheDirectory.appendingPathComponent(domain.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? domain)
        if let cached = try? Data(contentsOf: fileURL),
           let entry = try? JSONDecoder().decode(CacheEntry.self, from: cached),
           Date().timeIntervalSince(entry.date) < cacheDuration {
            memory[domain] = entry.data
            return entry.data
        }

        // Fetch from Google's favicon service
        guard let url = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  PlatformImage(data: data) != nil else {
                return nil
            }

            memory[domain] = data

            // Persist to disk
            if let encoded = try? JSONEncoder().encode(CacheEntry(data: data, date: Date())) {
                try? encoded.write(to: fileURL)
            }

            return data
        } catch {
            logger.warning("Favicon fetch failed for \(domain, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
