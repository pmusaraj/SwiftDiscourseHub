import SwiftUI

struct CompactTopicListView: View {
    let site: DiscourseSite
    @State private var selectedTopicId: Int?
    @State private var selectedTopic: Topic?
    @State private var topicCategories: [DiscourseCategory] = []
    @State private var topicVM = TopicListViewModel()

    private var resumePostNumber: Int? {
        guard site.isAuthenticated,
              let lastRead = selectedTopic?.lastReadPostNumber, lastRead > 0,
              let highest = selectedTopic?.highestPostNumber else { return nil }
        if lastRead < highest {
            return lastRead + 1  // Next unread post
        } else {
            return highest       // Fully read — scroll to last post
        }
    }

    var body: some View {
        TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories, topicVM: topicVM)
            .navigationDestination(item: $selectedTopicId) { topicId in
                TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories, startPostNumber: resumePostNumber)
            }
    }
}
