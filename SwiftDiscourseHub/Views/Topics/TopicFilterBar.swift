import SwiftUI

struct TopicFilterBar: View {
    @Bindable var viewModel: TopicListViewModel
    var isAuthenticated: Bool = false

    private var filters: [TopicFilter] {
        if isAuthenticated {
            return TopicFilter.allCases
        } else {
            return TopicFilter.allCases.filter { $0 != .new }
        }
    }

    var body: some View {
        Picker("", selection: $viewModel.filter) {
            ForEach(filters, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}
