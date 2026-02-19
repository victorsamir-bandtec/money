import SwiftUI
import SwiftData

struct DebtorsScene: View {
    @StateObject private var viewModel: DebtorsListViewModel
    @State private var showingCreateSheet = false
    @State private var draft = DebtorDraft()
    @State private var debtorPendingDeletion: Debtor?
    @State private var showingDeleteDebtorDialog = false
    @State private var selectedDebtor: Debtor?
    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
        _viewModel = StateObject(
            wrappedValue: DebtorsListViewModel(
                context: context,
                commandService: environment.commandService,
                metricsEngine: environment.debtorMetricsEngine,
                eventBus: environment.domainEventBus
            )
        )
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
                        AppEmptyState(
                            icon: viewModel.showArchived ? "archivebox" : "person.badge.plus",
                            title: "debtors.empty.title",
                            message: "debtors.empty.message",
                            actionTitle: "debtors.empty.action",
                            action: { showingCreateSheet = true }
                        )
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 40, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .transition(.opacity)
                    } else {
                        ForEach(viewModel.debtors, id: \.id) { debtor in
                            DebtorRow(
                                debtor: debtor,
                                summary: viewModel.summary(for: debtor),
                                profile: viewModel.creditProfile(for: debtor),
                                environment: environment
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDebtor = debtor
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    debtorPendingDeletion = debtor
                                    showingDeleteDebtorDialog = true
                                } label: {
                                    Label("debtors.row.delete", systemImage: "trash")
                                }
                                .tint(.red)
                                Button {
                                    viewModel.toggleArchive(debtor)
                                } label: {
                                    Label(debtor.archived ? "debtors.row.unarchive" : "debtors.row.archive", systemImage: debtor.archived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(debtor.archived ? .blue : .orange)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(AppBackground(variant: .debtors))
            .animation(.easeInOut(duration: 0.2), value: viewModel.debtors)
            .navigationTitle("debtors.title")
            .navigationDestination(item: $selectedDebtor) { debtor in
                DebtorDetailScene(debtor: debtor, environment: environment, context: context)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("debtors.add")
                }
            }
            .onChange(of: viewModel.searchText) {
                Task { await reload() }
            }
            .onChange(of: viewModel.showArchived) {
                Task { await reload() }
            }
            .onChange(of: showingDeleteDebtorDialog) { _, isPresented in
                if !isPresented {
                    debtorPendingDeletion = nil
                }
            }
            .task {
                await reload()
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
            .appErrorAlert(errorBinding)
            .confirmationDialog(
                String(localized: "debtors.delete.confirmation.title"),
                isPresented: $showingDeleteDebtorDialog,
                titleVisibility: .visible,
                presenting: debtorPendingDeletion
            ) { debtor in
                Button(String(localized: "debtors.delete.confirmation.confirm"), role: .destructive) {
                    viewModel.deleteDebtor(debtor)
                    debtorPendingDeletion = nil
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    debtorPendingDeletion = nil
                }
            } message: { debtor in
                Text(localizedFormat("debtors.delete.confirmation.message", debtor.name))
            }
        }
    }

    private var errorBinding: Binding<AppError?> {
        Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        )
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
    private func reload() async {
        await viewModel.loadAsync()
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
        VStack(alignment: .leading, spacing: 24) {
            // Título da seção (opcional, pode ser removido se redundante com o NavigationTitle)
            VStack(alignment: .leading, spacing: 4) {
                Text("debtors.summary.title")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("debtors.summary.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4) // Pequeno ajuste para alinhar visualmente com os cards

            // Destaques no topo: Ativos e Arquivados
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                MetricCard(
                    title: "debtors.metric.active",
                    value: String(metrics.active),
                    caption: "debtors.metric.active.caption",
                    icon: "person.3.sequence.fill",
                    tint: .green,
                    layoutMode: .uniform
                )
                MetricCard(
                    title: "debtors.metric.archived",
                    value: String(metrics.archived),
                    caption: "debtors.metric.archived.caption",
                    icon: "archivebox.fill",
                    tint: .orange,
                    layoutMode: .uniform
                )
            }

            // Campo de busca
            AppSearchField.forNames(text: $searchText, prompt: "debtors.search")

            // Filtro de exibição
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("debtors.filter.caption")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
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

private struct DebtorRow: View {
    let debtor: Debtor
    let summary: DebtorsListViewModel.DebtorSummary
    let profile: DebtorCreditProfileDTO?
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 12) {
                if summary.totalAgreements == 0 {
                    // Sem acordos cadastrados
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debtors.row.status.none")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if summary.remainingAmount == 0 {
                    // Dívidas quitadas
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debtors.row.status.settled")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Valor em aberto
                    HStack(spacing: 10) {
                        Image(systemName: "banknote.fill")
                            .font(.title3)
                            .foregroundStyle(remainingAmountColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedRemainingAmount)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("debtors.row.remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if summary.overdueInstallments > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text(installmentsText(for: summary.overdueInstallments, keyBase: "debtors.row.installments.overdue"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moneyCard(
            tint: cardTint,
            cornerRadius: 24,
            shadow: .compact,
            intensity: .subtle
        )
    }

    private var header: some View {
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

            if let profile = profile {
                CreditScoreBadge(score: profile.score, riskLevel: profile.riskLevel, style: .compact)
            }

            if debtor.archived {
                StatusBadge.archived()
            }
        }
    }

    private var formattedRemainingAmount: String {
        environment.currencyFormatter.string(from: summary.remainingAmount)
    }

    private var remainingAmountColor: Color {
        if summary.overdueInstallments > 0 {
            return .orange
        }
        return summary.remainingAmount > 0 ? .appThemeColor : .green
    }

    private func installmentsText(for count: Int, keyBase: String) -> String {
        if count == 1 {
            return localizedFormat("\(keyBase).single", count)
        }
        return localizedFormat("\(keyBase).multiple", count)
    }

    private var cardTint: Color {
        if debtor.archived { return .gray }
        if summary.overdueInstallments > 0 { return .orange }
        if summary.totalAgreements == 0 { return .orange }
        if summary.remainingAmount == 0 { return .green }
        return .appThemeColor
    }
}

private struct DebtorDraft: Equatable {
    var name: String = ""
    var phone: String = ""
    var note: String = ""
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
                .disabled(draft.name.isBlankOrEmpty)
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
    let debtor = Debtor(name: "Ana Paula", note: "Cliente antiga")!
    debtor.phone = "(11) 90000-0000"
    context.insert(debtor)
    return DebtorsScene(environment: AppEnvironment(), context: context)
}
