import SwiftUI

struct TopicFilterBar: View {
    @Bindable var viewModel: TopicListViewModel

    var body: some View {
        Picker("", selection: $viewModel.filter) {
            ForEach(TopicFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
