import Foundation
import SwiftData

@Observable
final class AddSiteViewModel {
    var urlText = ""
    var isValidating = false
    var validationError: String?
    var validatedInfo: SiteBasicInfoResponse?

    private let apiClient = DiscourseAPIClient()

    var normalizedURL: String {
        var url = urlText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }

    @MainActor
    func validate() async {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Please enter a URL"
            return
        }
        isValidating = true
        validationError = nil
        validatedInfo = nil

        do {
            let info = try await apiClient.fetchBasicInfo(baseURL: normalizedURL)
            if info.loginRequired == true {
                validationError = "This site requires login (not yet supported)"
            } else {
                validatedInfo = info
            }
        } catch {
            validationError = error.localizedDescription
        }
        isValidating = false
    }

    func addSite(context: ModelContext) {
        guard let info = validatedInfo else { return }
        let site = DiscourseSite(
            baseURL: normalizedURL,
            title: info.title ?? normalizedURL,
            iconURL: info.appleTouchIconUrl ?? info.faviconUrl,
            logoURL: info.logoUrl,
            siteDescription: info.description
        )
        context.insert(site)
        try? context.save()
    }

    func reset() {
        urlText = ""
        isValidating = false
        validationError = nil
        validatedInfo = nil
    }
}
