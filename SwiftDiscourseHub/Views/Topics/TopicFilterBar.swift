import SwiftUI

struct TopicFilterBar: View {
    @Bindable var viewModel: TopicListViewModel

    var body: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(TopicFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
