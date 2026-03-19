import SwiftUI

struct CompactTopicListView: View {
    let site: DiscourseSite
    @State private var selectedTopicId: Int?
    @State private var selectedTopic: Topic?
    @State private var topicCategories: [DiscourseCategory] = []
    @State private var topicVM = TopicListViewModel()

    var body: some View {
        TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories, topicVM: topicVM)
            .navigationDestination(item: $selectedTopicId) { topicId in
                TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories)
            }
    }
}
