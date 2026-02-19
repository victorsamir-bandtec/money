import Foundation
import Combine
import SwiftData

struct DashboardSummary: Sendable, Equatable {
    var salary: Decimal
    var received: Decimal
    var overdue: Decimal
    var fixedExpenses: Decimal
    var planned: Decimal
    var variableExpenses: Decimal
    var variableIncome: Decimal
    var remainingToReceive: Decimal
    var availableToSpend: Decimal

    init(
        salary: Decimal,
        received: Decimal,
        overdue: Decimal,
        fixedExpenses: Decimal,
        planned: Decimal,
        variableExpenses: Decimal = .zero,
        variableIncome: Decimal = .zero
    ) {
        self.salary = salary
        self.received = received
        self.overdue = overdue
        self.fixedExpenses = fixedExpenses
        self.planned = planned
        self.variableExpenses = variableExpenses
        self.variableIncome = variableIncome
        self.remainingToReceive = planned + overdue
        self.availableToSpend = (salary + received + variableIncome) - (fixedExpenses + variableExpenses)
    }

    var totalExpenses: Decimal {
        fixedExpenses + variableExpenses
    }

    var totalIncome: Decimal {
        salary + received + variableIncome
    }

    var variableBalance: Decimal {
        variableIncome - variableExpenses
    }

    static let empty = DashboardSummary(salary: .zero, received: .zero, overdue: .zero, fixedExpenses: .zero, planned: .zero)
}

struct InstallmentOverview: Identifiable, Equatable, Sendable {
    let id: UUID
    let agreementID: UUID
    let debtorName: String
    let agreementTitle: String?
    let dueDate: Date
    let amount: Decimal
    let status: InstallmentStatus
    let number: Int
    let isOverdue: Bool

    init(installment: Installment, agreement: DebtAgreement, referenceDate: Date = .now) {
        self.id = installment.id
        self.agreementID = agreement.id
        self.debtorName = agreement.debtor.name
        self.agreementTitle = agreement.title
        self.dueDate = installment.dueDate
        self.amount = installment.amount
        self.status = installment.status
        self.number = installment.number
        self.isOverdue = installment.isOverdue(relativeTo: referenceDate)
    }

    init(snapshot: UpcomingInstallmentSnapshot) {
        self.id = snapshot.id
        self.agreementID = snapshot.agreementID
        self.debtorName = snapshot.debtorName
        self.agreementTitle = snapshot.agreementTitle
        self.dueDate = snapshot.dueDate
        self.amount = snapshot.amount
        self.status = snapshot.status
        self.number = snapshot.number
        self.isOverdue = snapshot.isOverdue
    }

    var displayTitle: String {
        agreementTitle ?? debtorName
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    private let readModel: FinancialSummaryQuerying
    private let currencyFormatter: CurrencyFormatter
    private let eventBus: DomainEventSubscribing?
    private var eventTask: Task<Void, Never>?

    @Published var summary: DashboardSummary = .empty
    @Published var upcoming: [InstallmentOverview] = []
    @Published var alerts: [InstallmentOverview] = []

    init(
        context: ModelContext,
        currencyFormatter: CurrencyFormatter,
        readModel: FinancialSummaryQuerying? = nil,
        eventBus: DomainEventSubscribing? = nil
    ) {
        self.currencyFormatter = currencyFormatter
        self.readModel = readModel ?? FinancialReadModelService(context: context)
        self.eventBus = eventBus
        subscribeToEvents()
    }

    func load(currentDate: Date = .now) throws {
        try loadSummary(currentDate: currentDate)
        try loadInstallments(currentDate: currentDate)
    }

    func loadSummary(currentDate: Date = .now) throws {
        let snapshot = try readModel.summary(for: currentDate)
        summary = DashboardSummary(
            salary: snapshot.salary,
            received: snapshot.received,
            overdue: snapshot.overdue,
            fixedExpenses: snapshot.fixedExpenses,
            planned: snapshot.planned,
            variableExpenses: snapshot.variableExpenses,
            variableIncome: snapshot.variableIncome
        )
    }

    func loadInstallments(currentDate: Date = .now) throws {
        let snapshots = try readModel.upcomingInstallments(for: currentDate, windowDays: 14)
        let mapped = snapshots.map(InstallmentOverview.init(snapshot:))
        if mapped != upcoming {
            upcoming = mapped
            alerts = mapped
        }
    }

    func formatted(_ value: Decimal) -> String {
        currencyFormatter.string(from: value)
    }

    private func subscribeToEvents() {
        guard let eventBus else { return }

        eventTask = Task { [weak self] in
            let stream = await eventBus.stream()
            for await event in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                switch event {
                case .agreementChanged, .paymentChanged, .salaryChanged, .transactionChanged:
                    try? self.load()
                case .debtorChanged:
                    break
                }
            }
        }
    }
}
