import Foundation
import SwiftData

/// Agrega dados históricos em snapshots mensais.
/// Calcula sob demanda ao carregar a tela de análise histórica.
struct HistoricalAggregator: Sendable {

    /// Cria ou atualiza snapshot para um mês específico.
    /// - Parameters:
    ///   - month: Data dentro do mês desejado
    ///   - context: ModelContext para acesso aos dados
    ///   - calendar: Calendar para cálculos de data (padrão: .current)
    /// - Returns: MonthlySnapshot calculado para o mês
    func calculateSnapshot(
        for month: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> MonthlySnapshot {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        // Buscar snapshot existente
        let snapshotDescriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start &&
                snapshot.referenceMonth < monthInterval.end
            }
        )
        let existingSnapshot = try context.fetch(snapshotDescriptor).first
        let snapshot = existingSnapshot ?? MonthlySnapshot(referenceMonth: monthInterval.start)

        // 1. Calcular salário
        let salaryDescriptor = FetchDescriptor<SalarySnapshot>(
            predicate: #Predicate { sal in
                sal.referenceMonth >= monthInterval.start &&
                sal.referenceMonth < monthInterval.end
            }
        )
        let salaries = try context.fetch(salaryDescriptor)
        snapshot.salary = salaries.reduce(.zero) { $0 + $1.amount }

        // 2. Calcular pagamentos recebidos
        let paymentsDescriptor = FetchDescriptor<Payment>(
            predicate: #Predicate { payment in
                payment.date >= monthInterval.start &&
                payment.date < monthInterval.end
            }
        )
        let payments = try context.fetch(paymentsDescriptor)
        snapshot.paymentsReceived = payments.reduce(.zero) { $0 + $1.amount }

        // 3. Calcular transações variáveis (income e expenses)
        let transactionsDescriptor = FetchDescriptor<CashTransaction>(
            predicate: #Predicate { tx in
                tx.date >= monthInterval.start &&
                tx.date < monthInterval.end
            }
        )
        let transactions = try context.fetch(transactionsDescriptor)
        snapshot.variableIncome = transactions
            .filter { $0.type == .income }
            .reduce(.zero) { $0 + $1.amount }
        snapshot.variableExpenses = transactions
            .filter { $0.type == .expense }
            .reduce(.zero) { $0 + $1.amount }

        // 4. Calcular despesas fixas (média mensal das despesas ativas)
        let expensesDescriptor = FetchDescriptor<FixedExpense>(
            predicate: #Predicate { $0.active }
        )
        let expenses = try context.fetch(expensesDescriptor)
        snapshot.fixedExpenses = expenses.reduce(.zero) { $0 + $1.amount }

        // 5. Calcular métricas de devedores (no final do mês)
        let monthEnd = monthInterval.end
        let paidStatusRawValue = InstallmentStatus.paid.rawValue
        let overdueDescriptor = FetchDescriptor<Installment>(
            predicate: #Predicate { installment in
                installment.dueDate < monthEnd &&
                installment.statusRaw != paidStatusRawValue
            }
        )
        let overdueInstallments = try context.fetch(overdueDescriptor)
        // Forçar carregamento de paidAmount (computed property)
        overdueInstallments.forEach { _ = $0.paidAmount }
        snapshot.overdueAmount = overdueInstallments
            .filter { $0.remainingAmount > .zero }
            .reduce(.zero) { $0 + $1.remainingAmount }

        let debtorsDescriptor = FetchDescriptor<Debtor>(
            predicate: #Predicate { !$0.archived }
        )
        let debtors = try context.fetch(debtorsDescriptor)
        snapshot.activeDebtors = debtors.filter { debtor in
            debtor.agreements.contains { !$0.closed }
        }.count

        let agreementsDescriptor = FetchDescriptor<DebtAgreement>(
            predicate: #Predicate { !$0.closed }
        )
        snapshot.activeAgreements = try context.fetch(agreementsDescriptor).count

        // 6. Recalcular totais
        snapshot.totalIncome = snapshot.salary + snapshot.paymentsReceived + snapshot.variableIncome
        snapshot.totalExpenses = snapshot.fixedExpenses + snapshot.variableExpenses
        snapshot.netBalance = snapshot.totalIncome - snapshot.totalExpenses

        // 7. Persistir se novo
        if existingSnapshot == nil {
            context.insert(snapshot)
        }
        try context.save()

        return snapshot
    }

    /// Busca snapshot de um mês específico.
    /// - Parameters:
    ///   - month: Data dentro do mês desejado
    ///   - context: ModelContext para acesso aos dados
    ///   - calendar: Calendar para cálculos de data
    /// - Returns: MonthlySnapshot se existir, nil caso contrário
    func fetchSnapshot(
        for month: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> MonthlySnapshot? {
        let monthInterval = calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, end: month)

        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= monthInterval.start &&
                snapshot.referenceMonth < monthInterval.end
            }
        )
        return try context.fetch(descriptor).first
    }

    /// Busca snapshots de um período (ex: últimos 6 meses).
    /// - Parameters:
    ///   - startMonth: Data de início do período
    ///   - endMonth: Data de fim do período
    ///   - context: ModelContext para acesso aos dados
    /// - Returns: Array de MonthlySnapshot ordenados por data
    func fetchSnapshots(
        from startMonth: Date,
        to endMonth: Date,
        context: ModelContext
    ) throws -> [MonthlySnapshot] {
        let descriptor = FetchDescriptor<MonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.referenceMonth >= startMonth &&
                snapshot.referenceMonth <= endMonth
            },
            sortBy: [SortDescriptor(\.referenceMonth, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Calcula taxa de crescimento entre dois valores.
    /// - Parameters:
    ///   - current: Valor atual
    ///   - previous: Valor anterior
    /// - Returns: Taxa de crescimento (ex: 0.15 = 15%), nil se valor anterior for zero
    func calculateGrowthRate(current: Decimal, previous: Decimal) -> Double? {
        guard previous > 0 else { return nil }
        let growth = (current - previous) / previous
        return Double(truncating: NSDecimalNumber(decimal: growth))
    }
}
