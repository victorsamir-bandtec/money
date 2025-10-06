import SwiftUI
import SwiftData

struct DebtorsScene: View {
    @StateObject private var viewModel: DebtorsListViewModel
    @State private var showingCreateSheet = false
    @State private var draft = DebtorDraft()
    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
        _viewModel = StateObject(wrappedValue: DebtorsListViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DebtorsSummaryCard(
                        metrics: summaryMetrics,
                        searchText: $viewModel.searchText,
                        filter: archiveFilterBinding
                    )
                    .listRowInsets(EdgeInsets(top: 32, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    if viewModel.debtors.isEmpty {
                        DebtorsEmptyState(showArchived: viewModel.showArchived) {
                            showingCreateSheet = true
                        }
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 40, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .transition(.opacity)
                    } else {
                        ForEach(viewModel.debtors, id: \.id) { debtor in
                            NavigationLink(destination: DebtorDetailScene(debtor: debtor, environment: environment, context: context)) {
                                DebtorRow(debtor: debtor)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.toggleArchive(debtor)
                                } label: {
                                    Label(debtor.archived ? "debtors.row.unarchive" : "debtors.row.archive", systemImage: debtor.archived ? "tray.and.arrow.up" : "archivebox")
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(DebtorsBackground())
            .animation(.easeInOut(duration: 0.2), value: viewModel.debtors)
            .navigationTitle("debtors.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("debtors.add")
                }
            }
            .onChange(of: viewModel.searchText) { _ in
                reload()
            }
            .onChange(of: viewModel.showArchived) { _ in
                reload()
            }
            .task {
                reload()
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationStack {
                    DebtorForm(draft: $draft) { action in
                        switch action {
                        case .save(let draft):
                            viewModel.addDebtor(name: draft.name, phone: draft.phone, note: draft.note)
                            showingCreateSheet = false
                        case .cancel:
                            showingCreateSheet = false
                        }
                    }
                }
            }
            .alert(item: Binding(get: {
                viewModel.error.map { LocalizedErrorWrapper(error: $0) }
            }, set: { _ in viewModel.error = nil })) { wrapper in
                Alert(title: Text("error.title"), message: Text(wrapper.localizedDescription))
            }
        }
    }

    private var archiveFilterBinding: Binding<ArchiveFilter> {
        Binding(
            get: { viewModel.showArchived ? .includeArchived : .activeOnly },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showArchived = (newValue == .includeArchived)
                }
            }
        )
    }

    private var summaryMetrics: DebtorsSummaryMetrics {
        DebtorsSummaryMetrics(
            active: viewModel.activeCount,
            archived: viewModel.archivedCount
        )
    }

    @MainActor
    private func reload() {
        try? viewModel.load()
    }
}

private enum ArchiveFilter: Hashable {
    case activeOnly
    case includeArchived
}

private struct DebtorsSummaryMetrics {
    let active: Int
    let archived: Int
}

private struct DebtorsSummaryCard: View {
    let metrics: DebtorsSummaryMetrics
    @Binding var searchText: String
    @Binding var filter: ArchiveFilter

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Título da página
            VStack(alignment: .leading, spacing: 4) {
                Text("debtors.summary.title")
                    .font(.title2)
                    .bold()
                Text("debtors.summary.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Destaques no topo: Ativos e Arquivados
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "debtors.metric.active",
                    value: String(metrics.active),
                    caption: "debtors.metric.active.caption",
                    icon: "person.3.sequence.fill",
                    tint: .green
                )
                MetricCard(
                    title: "debtors.metric.archived",
                    value: String(metrics.archived),
                    caption: "debtors.metric.archived.caption",
                    icon: "archivebox.fill",
                    tint: .orange
                )
            }

            // Campo de busca
            DebtorsSearchField(text: $searchText)

            // Filtro de exibição
            VStack(alignment: .leading, spacing: 8) {
                Text("debtors.filter.caption")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("debtors.filter.caption", selection: $filter) {
                    Text("debtors.filter.active")
                        .tag(ArchiveFilter.activeOnly)
                    Text("debtors.filter.all")
                        .tag(ArchiveFilter.includeArchived)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DebtorsSearchField: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("debtors.search", text: $text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("debtors.search.clear")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(strokeColor)
        )
    }

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}

private struct DebtorsEmptyState: View {
    var showArchived: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: showArchived ? "archivebox" : "person.badge.plus")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("debtors.empty.title")
                .font(.headline)

            Text("debtors.empty.message")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: onAdd) {
                Text("debtors.empty.action")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            GlassBackgroundStyle.current.material,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

private struct DebtorRow: View {
    let debtor: Debtor
    @Environment(\.colorScheme) private var colorScheme

    private var agreementText: String {
        switch debtor.agreements.count {
        case 0:
            return String(localized: "debtors.row.agreements.none")
        case 1:
            return localizedFormat("debtors.row.agreements.single", debtor.agreements.count)
        default:
            return localizedFormat("debtors.row.agreements.multiple", debtor.agreements.count)
        }
    }

    private var agreementIcon: String {
        debtor.agreements.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private var agreementTint: Color {
        if debtor.archived { return .gray }
        return debtor.agreements.isEmpty ? .orange : .green
    }

    private var baseFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                DebtorAvatar(initials: debtor.initials)

                VStack(alignment: .leading, spacing: 6) {
                    Text(debtor.name)
                        .font(.headline.weight(.semibold))
                    if let note = debtor.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if debtor.archived {
                    Text("debtors.row.archived")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.18), in: Capsule())
                }
            }

            InfoChip(text: agreementText, systemImage: agreementIcon, tint: agreementTint)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(baseFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12))
        )
    }
}

private struct InfoChip: View {
    let text: String
    let systemImage: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.12))
            )
            .foregroundStyle(foregroundColor)
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.92)
            : tint
    }
}

private struct DebtorsBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 1 : 0.6)
            RadialGradient(
                colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.12), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.08, blue: 0.13),
                Color(red: 0.01, green: 0.02, blue: 0.05)
            ]
        }
        return [
            Color(.systemGroupedBackground),
            Color(.secondarySystemGroupedBackground)
        ]
    }
}

private struct DebtorDraft: Equatable {
    var name: String = ""
    var phone: String = ""
    var note: String = ""
}

private struct LocalizedErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError

    var localizedDescription: String {
        error.errorDescription ?? ""
    }
}

private struct DebtorForm: View {
    @Binding var draft: DebtorDraft
    var completion: (ResultAction) -> Void

    var body: some View {
        Form {
            Section("debtors.form.info") {
                TextField("debtors.form.name", text: $draft.name)
                    .textContentType(.name)
                TextField("debtors.form.phone", text: $draft.phone)
                    .keyboardType(.phonePad)
                TextField("debtors.form.note", text: $draft.note, axis: .vertical)
            }
        }
        .navigationTitle("debtors.form.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") {
                    completion(.cancel)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save") {
                    completion(.save(draft))
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    enum ResultAction {
        case save(DebtorDraft)
        case cancel
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema([Debtor.self, DebtAgreement.self]), configurations: configuration)
    let context = container.mainContext
    let debtor = Debtor(name: "Ana Paula", note: "Cliente antiga")
    debtor.phone = "(11) 90000-0000"
    context.insert(debtor)
    return DebtorsScene(environment: AppEnvironment(), context: context)
}
