import SwiftUI
import SwiftData

struct SiteSidebarView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @Binding var selectedSite: DiscourseSite?
    @Binding var showingDiscover: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 6) {
            ForEach(sites) { site in
                SiteIconView(site: site, isSelected: selectedSite?.baseURL == site.baseURL && !showingDiscover)
                    .onTapGesture {
                        selectedSite = site
                        showingDiscover = false
                    }
                    .contextMenu {
                        Button("Remove Site", role: .destructive) {
                            if selectedSite?.baseURL == site.baseURL {
                                selectedSite = nil
                            }
                            modelContext.delete(site)
                            try? modelContext.save()
                        }
                    }
            }

            Spacer()

            Button {
                selectedSite = nil
                showingDiscover = true
            } label: {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(showingDiscover && selectedSite == nil ? Color.accentColor : Color.secondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .help("Discover Communities")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(width: 80)
        .frame(maxHeight: .infinity)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            if selectedSite == nil, let first = sites.first {
                selectedSite = first
            }
        }
    }
}
