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
    let currencyFormatter: CurrencyFormatter
    private var lastLoadedDebtorId: UUID?
    private let cacheDuration: TimeInterval = 300

    init(context: ModelContext, currencyFormatter: CurrencyFormatter) {
        self.context = context
        self.calculator = CreditScoreCalculator()
        self.currencyFormatter = currencyFormatter
    }

    func loadProfile(for debtor: Debtor) async {
        if shouldUseCachedProfile(for: debtor) {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            profile = try calculator.calculateProfile(for: debtor, context: context)
            lastLoadedDebtorId = debtor.id
        } catch {
            self.error = .persistence("error.generic")
        }
    }

    func recalculate(for debtor: Debtor) async {
        lastLoadedDebtorId = nil
        await loadProfile(for: debtor)
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
