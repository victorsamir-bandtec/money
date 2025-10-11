import Foundation
import SwiftData
import SwiftUI

@Model final class DebtorCreditProfile {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor

    var score: Int
    var riskLevelRaw: String
    var lastCalculated: Date

    var totalAgreements: Int
    var totalInstallments: Int
    var paidOnTimeCount: Int
    var paidLateCount: Int
    var overdueCount: Int
    var averageDaysLate: Double
    var onTimePaymentRate: Double

    var totalLent: Decimal
    var totalPaid: Decimal
    var totalInterestEarned: Decimal
    var currentOutstanding: Decimal

    var firstAgreementDate: Date?
    var lastPaymentDate: Date?
    var consecutiveOnTimePayments: Int
    var longestDelayDays: Int

    var riskLevel: RiskLevel {
        get { RiskLevel(rawValue: riskLevelRaw) ?? .medium }
        set { riskLevelRaw = newValue.rawValue }
    }

    var returnOnInvestment: Decimal {
        guard totalLent > 0 else { return 0 }
        return (totalInterestEarned / totalLent) * 100
    }

    var profitMargin: Decimal {
        guard totalPaid > 0 else { return 0 }
        return (totalInterestEarned / totalPaid) * 100
    }

    var collectionRate: Double {
        guard totalLent > 0 else { return 0 }
        return Double(truncating: (totalPaid / totalLent) as NSDecimalNumber)
    }

    init(
        id: UUID = UUID(),
        debtor: Debtor,
        score: Int = 50,
        riskLevel: RiskLevel = .medium,
        lastCalculated: Date = .now
    ) {
        self.id = id
        self.debtor = debtor
        self.score = score
        self.riskLevelRaw = riskLevel.rawValue
        self.lastCalculated = lastCalculated
        self.totalAgreements = 0
        self.totalInstallments = 0
        self.paidOnTimeCount = 0
        self.paidLateCount = 0
        self.overdueCount = 0
        self.averageDaysLate = 0
        self.onTimePaymentRate = 0
        self.totalLent = .zero
        self.totalPaid = .zero
        self.totalInterestEarned = .zero
        self.currentOutstanding = .zero
        self.consecutiveOnTimePayments = 0
        self.longestDelayDays = 0
    }
}

enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.shield.fill"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .low: return "credit.risk.low"
        case .medium: return "credit.risk.medium"
        case .high: return "credit.risk.high"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .low: return "credit.risk.low.description"
        case .medium: return "credit.risk.medium.description"
        case .high: return "credit.risk.high.description"
        }
    }
}
