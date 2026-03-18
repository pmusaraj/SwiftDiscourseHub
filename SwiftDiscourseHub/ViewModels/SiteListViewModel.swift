import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class SiteListViewModel {
    var showingAddSite = false

    func deleteSite(_ site: DiscourseSite, context: ModelContext) {
        context.delete(site)
        try? context.save()
    }
}
