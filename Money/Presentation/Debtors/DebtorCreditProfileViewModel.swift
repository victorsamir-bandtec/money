import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorCreditProfileViewModel: ObservableObject {
    @Published private(set) var profile: DebtorCreditProfile?
    @Published private(set) var isLoading = false
    @Published var error: AppError?

    private let context: ModelContext
    private let calculator: CreditScoreCalculator
    private let commandService: CommandService?
    let currencyFormatter: CurrencyFormatter
    private var lastLoadedDebtorId: UUID?
    private let cacheDuration: TimeInterval = 300

    init(
        context: ModelContext,
        currencyFormatter: CurrencyFormatter,
        commandService: CommandService? = nil
    ) {
        self.context = context
        self.calculator = CreditScoreCalculator()
        self.commandService = commandService
        self.currencyFormatter = currencyFormatter
    }

    func loadProfile(for debtor: Debtor) async {
        if shouldUseCachedProfile(for: debtor) {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let debtorID = debtor.id
            let descriptor = FetchDescriptor<DebtorCreditProfile>(predicate: #Predicate { profile in
                profile.debtor.id == debtorID
            })
            profile = try context.fetch(descriptor).first
            lastLoadedDebtorId = debtor.id
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func recalculate(for debtor: Debtor) async {
        lastLoadedDebtorId = nil
        do {
            if let commandService {
                _ = try commandService.recalculateCreditProfile(
                    for: debtor,
                    calculator: calculator,
                    context: context
                )
            } else {
                _ = try calculator.calculateProfile(for: debtor, context: context)
            }
            await loadProfile(for: debtor)
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    private func shouldUseCachedProfile(for debtor: Debtor) -> Bool {
        guard let profile,
              lastLoadedDebtorId == debtor.id else {
            return false
        }
        let timeSinceLastCalculation = Date.now.timeIntervalSince(profile.lastCalculated)
        return timeSinceLastCalculation < cacheDuration
    }

    func formattedScore() -> String {
        guard let profile else { return "--" }
        return "\(profile.score)"
    }

    func formattedOnTimeRate() -> String {
        guard let profile else { return "0%" }
        return "\(Int(profile.onTimePaymentRate * 100))%"
    }

    func formattedAverageDelay() -> String {
        guard let profile else { return "--" }
        let days = Int(profile.averageDaysLate)
        return String(localized: "credit.days.format", defaultValue: "\(days) dias")
    }

    func formattedTotalInterest() -> String {
        guard let profile else { return currencyFormatter.string(from: .zero) }
        return currencyFormatter.string(from: profile.totalInterestEarned)
    }

    func formattedCurrentOutstanding() -> String {
        guard let profile else { return currencyFormatter.string(from: .zero) }
        return currencyFormatter.string(from: profile.currentOutstanding)
    }

    func formattedROI() -> String {
        guard let profile else { return "0%" }
        let roi = profile.returnOnInvestment
        return String(format: "%.1f%%", NSDecimalNumber(decimal: roi).doubleValue)
    }

    func formattedCollectionRate() -> String {
        guard let profile else { return "0%" }
        return "\(Int(profile.collectionRate * 100))%"
    }
}
