import Foundation
import SwiftData

struct DebtorSummaryDTO: Equatable, Sendable {
    let totalAgreements: Int
    let activeAgreements: Int
    let totalInstallments: Int
    let paidInstallments: Int
    let openInstallments: Int
    let overdueInstallments: Int
    let totalAmount: Decimal
    let paidAmount: Decimal

    var remainingAmount: Decimal {
        (totalAmount - paidAmount).clamped(to: .zero...totalAmount)
    }

    static let empty = DebtorSummaryDTO(
        totalAgreements: 0,
        activeAgreements: 0,
        totalInstallments: 0,
        paidInstallments: 0,
        openInstallments: 0,
        overdueInstallments: 0,
        totalAmount: .zero,
        paidAmount: .zero
    )
}

struct DebtorCreditProfileDTO: Equatable, Sendable {
    let debtorID: UUID
    let score: Int
    let riskLevel: RiskLevel
    let lastCalculated: Date
}

protocol DebtorMetricsProviding: Sendable {
    func summaries(for debtorIDs: [UUID]) async throws -> [UUID: DebtorSummaryDTO]
    func profiles(for debtorIDs: [UUID]) async throws -> [UUID: DebtorCreditProfileDTO]
    func invalidate(debtorIDs: Set<UUID>?) async
}

actor DebtorMetricsEngine: DebtorMetricsProviding {
    private struct Cached<T: Sendable>: Sendable {
        let value: T
        let date: Date
    }

    private let container: ModelContainer
    private var summaryCache: [UUID: Cached<DebtorSummaryDTO>] = [:]
    private var profileCache: [UUID: Cached<DebtorCreditProfileDTO>] = [:]
    private let cacheTTL: TimeInterval

    init(container: ModelContainer, cacheTTL: TimeInterval = 120) {
        self.container = container
        self.cacheTTL = cacheTTL
    }

    func invalidate(debtorIDs: Set<UUID>? = nil) async {
        guard let debtorIDs else {
            summaryCache.removeAll()
            profileCache.removeAll()
            return
        }

        for debtorID in debtorIDs {
            summaryCache[debtorID] = nil
            profileCache[debtorID] = nil
        }
    }

    func summaries(for debtorIDs: [UUID]) async throws -> [UUID: DebtorSummaryDTO] {
        let now = Date.now
        let ids = Set(debtorIDs)
        var output: [UUID: DebtorSummaryDTO] = [:]
        var missing: [UUID] = []

        for debtorID in ids {
            if let cached = summaryCache[debtorID], now.timeIntervalSince(cached.date) <= cacheTTL {
                output[debtorID] = cached.value
            } else {
                missing.append(debtorID)
            }
        }

        guard !missing.isEmpty else { return output }

        let context = ModelContext(container)
        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(predicate: #Predicate { agreement in
            ids.contains(agreement.debtor.id)
        })
        let installmentsDescriptor = FetchDescriptor<Installment>(predicate: #Predicate { installment in
            ids.contains(installment.agreement.debtor.id)
        })

        let agreements = try context.fetch(agreementsDescriptor)
        let installments = try context.fetch(installmentsDescriptor)

        var agreementsByDebtor: [UUID: [DebtAgreement]] = [:]
        agreements.forEach { agreement in
            agreementsByDebtor[agreement.debtor.id, default: []].append(agreement)
        }

        var installmentsByAgreement: [UUID: [Installment]] = [:]
        installments.forEach { installment in
            installmentsByAgreement[installment.agreement.id, default: []].append(installment)
        }

        for debtorID in missing {
            let debtorAgreements = agreementsByDebtor[debtorID] ?? []
            var closedMap: [UUID: Bool] = [:]
            for agreement in debtorAgreements {
                let related = installmentsByAgreement[agreement.id] ?? []
                let isClosed = !related.isEmpty && related.allSatisfy { $0.status == .paid }
                closedMap[agreement.id] = isClosed
            }

            let activeAgreements = debtorAgreements.filter { !(closedMap[$0.id] ?? $0.closed) }
            let activeAgreementIDs = Set(activeAgreements.map(\.id))
            let activeInstallments = installments
                .filter { $0.agreement.debtor.id == debtorID && activeAgreementIDs.contains($0.agreement.id) }

            let totalInstallments = activeInstallments.count
            let paidInstallments = activeInstallments.filter { $0.status == .paid }.count
            let openInstallments = max(totalInstallments - paidInstallments, 0)
            let overdueInstallments = activeInstallments.filter { $0.isOverdue }.count
            let totalAmount = activeInstallments.reduce(.zero) { $0 + $1.amount }
            let paidAmount = activeInstallments.reduce(.zero) { $0 + min($1.paidAmount, $1.amount) }

            let summary = DebtorSummaryDTO(
                totalAgreements: debtorAgreements.count,
                activeAgreements: activeAgreements.count,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments,
                openInstallments: openInstallments,
                overdueInstallments: overdueInstallments,
                totalAmount: totalAmount,
                paidAmount: paidAmount
            )

            summaryCache[debtorID] = Cached(value: summary, date: now)
            output[debtorID] = summary
        }

        return output
    }

    func profiles(for debtorIDs: [UUID]) async throws -> [UUID: DebtorCreditProfileDTO] {
        let now = Date.now
        let ids = Set(debtorIDs)
        var output: [UUID: DebtorCreditProfileDTO] = [:]
        var missing: [UUID] = []

        for debtorID in ids {
            if let cached = profileCache[debtorID], now.timeIntervalSince(cached.date) <= cacheTTL {
                output[debtorID] = cached.value
            } else {
                missing.append(debtorID)
            }
        }

        guard !missing.isEmpty else { return output }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DebtorCreditProfile>(predicate: #Predicate { profile in
            ids.contains(profile.debtor.id)
        })

        let profiles = try context.fetch(descriptor)
        for profile in profiles {
            let dto = DebtorCreditProfileDTO(
                debtorID: profile.debtor.id,
                score: profile.score,
                riskLevel: profile.riskLevel,
                lastCalculated: profile.lastCalculated
            )
            profileCache[profile.debtor.id] = Cached(value: dto, date: now)
            output[profile.debtor.id] = dto
        }

        return output
    }
}
