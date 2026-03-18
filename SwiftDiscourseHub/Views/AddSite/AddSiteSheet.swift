import SwiftUI

struct AddSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient
    @State private var viewModel = AddSiteViewModel()
    @State private var showDiscover = false
    @State private var selectedDiscoverSite: DiscoverSite?

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter Site URL") {
                    TextField("discourse.example.com", text: $viewModel.urlText)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await viewModel.validate() }
                        }

                    if viewModel.isValidating {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Validating...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = viewModel.validationError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    if let info = viewModel.validatedInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.title ?? "Unknown Site")
                                .font(.headline)
                            if let desc = info.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if viewModel.validatedInfo != nil {
                    Section {
                        Button("Add Site") {
                            viewModel.addSite(context: modelContext)
                            dismiss()
                        }
                        .bold()
                    }
                }

                Section {
                    Button("Browse Popular Sites") {
                        showDiscover = true
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Site")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.validatedInfo == nil {
                        Button("Check") {
                            Task { await viewModel.validate() }
                        }
                        .disabled(viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isValidating)
                    }
                }
            }
            .navigationDestination(isPresented: $showDiscover) {
                DiscoverSitesView(selectedDiscoverSite: $selectedDiscoverSite)
            }
            .onAppear { viewModel.apiClient = apiClient }
        }
    }
}
