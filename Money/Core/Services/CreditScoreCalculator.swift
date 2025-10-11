import Foundation
import SwiftData

struct CreditScoreCalculator: Sendable {
    private enum ScoreWeights {
        static let onTimePaymentRate: Double = 0.40
        static let averageDelayPenalty: Double = 0.25
        static let currentOverduePenalty: Double = 0.20
        static let relationshipBonus: Double = 0.10
        static let recentTrendBonus: Double = 0.05
    }

    func calculateProfile(
        for debtor: Debtor,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DebtorCreditProfile {
        let debtorId = debtor.id
        var profileDescriptor = FetchDescriptor<DebtorCreditProfile>(
            predicate: #Predicate { $0.debtor.id == debtorId }
        )
        let existingProfile = try context.fetch(profileDescriptor).first
        let profile = existingProfile ?? DebtorCreditProfile(debtor: debtor)

        var agreementsDescriptor = FetchDescriptor<DebtAgreement>(
            predicate: #Predicate { $0.debtor.id == debtorId }
        )
        let agreements = try context.fetch(agreementsDescriptor)

        guard !agreements.isEmpty else {
            profile.score = 50
            profile.riskLevel = .medium
            profile.lastCalculated = .now
            if existingProfile == nil { context.insert(profile) }
            try context.save()
            return profile
        }

        var allInstallments: [Installment] = []
        for agreement in agreements {
            allInstallments.append(contentsOf: agreement.installments)
        }

        let metrics = calculateMetrics(
            installments: allInstallments,
            agreements: agreements,
            calendar: calendar
        )

        let score = calculateScore(from: metrics)
        let riskLevel = determineRiskLevel(score: score)

        profile.score = score
        profile.riskLevel = riskLevel
        profile.lastCalculated = .now
        profile.totalAgreements = metrics.totalAgreements
        profile.totalInstallments = metrics.totalInstallments
        profile.paidOnTimeCount = metrics.paidOnTimeCount
        profile.paidLateCount = metrics.paidLateCount
        profile.overdueCount = metrics.overdueCount
        profile.averageDaysLate = metrics.averageDaysLate
        profile.onTimePaymentRate = metrics.onTimePaymentRate
        profile.totalLent = metrics.totalLent
        profile.totalPaid = metrics.totalPaid
        profile.totalInterestEarned = metrics.totalInterestEarned
        profile.currentOutstanding = metrics.currentOutstanding
        profile.firstAgreementDate = metrics.firstAgreementDate
        profile.lastPaymentDate = metrics.lastPaymentDate
        profile.consecutiveOnTimePayments = metrics.consecutiveOnTimePayments
        profile.longestDelayDays = metrics.longestDelayDays

        if existingProfile == nil { context.insert(profile) }
        try context.save()

        return profile
    }

    private struct Metrics {
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
    }

    private func calculateMetrics(
        installments: [Installment],
        agreements: [DebtAgreement],
        calendar: Calendar
    ) -> Metrics {
        let today = calendar.startOfDay(for: .now)

        var paidOnTimeCount = 0
        var paidLateCount = 0
        var overdueCount = 0
        var totalDaysLate = 0
        var latePaymentsCount = 0
        var totalPaid = Decimal.zero
        var totalLent = Decimal.zero
        var totalInterestEarned = Decimal.zero
        var currentOutstanding = Decimal.zero
        var lastPaymentDate: Date?
        var firstAgreementDate: Date?
        var currentStreak = 0
        var longestDelayDays = 0

        for agreement in agreements {
            totalLent += agreement.principal

            if let rate = agreement.interestRateMonthly, rate > 0 {
                let totalWithInterest = agreement.installments.reduce(Decimal.zero) { $0 + $1.amount }
                let interest = totalWithInterest - agreement.principal
                totalInterestEarned += interest
            }

            if firstAgreementDate == nil || agreement.startDate < firstAgreementDate! {
                firstAgreementDate = agreement.startDate
            }
        }

        let sortedInstallments = installments.sorted { $0.dueDate < $1.dueDate }

        for installment in sortedInstallments {
            totalPaid += installment.paidAmount

            if installment.status == .paid {
                if let payment = installment.payments.first {
                    let daysLate = calendar.dateComponents([.day], from: installment.dueDate, to: payment.date).day ?? 0

                    if daysLate <= 0 {
                        paidOnTimeCount += 1
                        currentStreak += 1
                    } else {
                        paidLateCount += 1
                        totalDaysLate += daysLate
                        latePaymentsCount += 1
                        currentStreak = 0
                        longestDelayDays = max(longestDelayDays, daysLate)
                    }

                    if lastPaymentDate == nil || payment.date > lastPaymentDate! {
                        lastPaymentDate = payment.date
                    }
                }
            } else if installment.dueDate < today && installment.remainingAmount > 0 {
                overdueCount += 1
                let daysLate = calendar.dateComponents([.day], from: installment.dueDate, to: today).day ?? 0
                totalDaysLate += daysLate
                latePaymentsCount += 1
                currentStreak = 0
                longestDelayDays = max(longestDelayDays, daysLate)
                currentOutstanding += installment.remainingAmount
            } else if installment.remainingAmount > 0 {
                currentOutstanding += installment.remainingAmount
            }
        }

        let paidInstallments = paidOnTimeCount + paidLateCount
        let onTimePaymentRate = paidInstallments > 0 ? Double(paidOnTimeCount) / Double(paidInstallments) : 0
        let averageDaysLate = latePaymentsCount > 0 ? Double(totalDaysLate) / Double(latePaymentsCount) : 0

        return Metrics(
            totalAgreements: agreements.count,
            totalInstallments: installments.count,
            paidOnTimeCount: paidOnTimeCount,
            paidLateCount: paidLateCount,
            overdueCount: overdueCount,
            averageDaysLate: averageDaysLate,
            onTimePaymentRate: onTimePaymentRate,
            totalLent: totalLent,
            totalPaid: totalPaid,
            totalInterestEarned: totalInterestEarned,
            currentOutstanding: currentOutstanding,
            firstAgreementDate: firstAgreementDate,
            lastPaymentDate: lastPaymentDate,
            consecutiveOnTimePayments: currentStreak,
            longestDelayDays: longestDelayDays
        )
    }

    private func calculateScore(from metrics: Metrics) -> Int {
        var score = 0.0

        score += calculateOnTimeScore(metrics.onTimePaymentRate)
        score += calculateDelayPenalty(metrics.averageDaysLate)
        score += calculateOverduePenalty(metrics.overdueCount)
        score += calculateRelationshipBonus(metrics.firstAgreementDate)
        score += calculateTrendBonus(metrics.consecutiveOnTimePayments)

        return max(0, min(100, Int(score.rounded())))
    }

    private func calculateOnTimeScore(_ rate: Double) -> Double {
        rate * 100 * ScoreWeights.onTimePaymentRate
    }

    private func calculateDelayPenalty(_ averageDaysLate: Double) -> Double {
        if averageDaysLate == 0 {
            return ScoreWeights.averageDelayPenalty * 100
        }
        let normalizedDelay = min(averageDaysLate / 30.0, 1.0)
        return (1.0 - normalizedDelay) * ScoreWeights.averageDelayPenalty * 100
    }

    private func calculateOverduePenalty(_ overdueCount: Int) -> Double {
        if overdueCount == 0 {
            return ScoreWeights.currentOverduePenalty * 100
        }
        let normalizedOverdue = min(Double(overdueCount) / 5.0, 1.0)
        return (1.0 - normalizedOverdue) * ScoreWeights.currentOverduePenalty * 100
    }

    private func calculateRelationshipBonus(_ firstDate: Date?) -> Double {
        guard let firstDate else { return 0 }
        let monthsActive = Calendar.current.dateComponents([.month], from: firstDate, to: .now).month ?? 0
        let normalizedMonths = min(Double(monthsActive) / 12.0, 1.0)
        return normalizedMonths * ScoreWeights.relationshipBonus * 100
    }

    private func calculateTrendBonus(_ consecutivePayments: Int) -> Double {
        if consecutivePayments >= 3 {
            return ScoreWeights.recentTrendBonus * 100
        }
        return Double(consecutivePayments) * (ScoreWeights.recentTrendBonus * 100 / 3.0)
    }

    private func determineRiskLevel(score: Int) -> RiskLevel {
        switch score {
        case 75...100: return .low
        case 40..<75: return .medium
        default: return .high
        }
    }
}
