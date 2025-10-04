import Foundation
import SwiftData

@Model final class Debtor {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String?
    var note: String?
    @Relationship(deleteRule: .cascade) var agreements: [DebtAgreement]
    var createdAt: Date
    var archived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        phone: String? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        archived: Bool = false
    ) {
        precondition(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        self.id = id
        self.name = name
        self.phone = phone
        self.note = note
        self.agreements = []
        self.createdAt = createdAt
        self.archived = archived
    }
}

@Model final class DebtAgreement {
    @Attribute(.unique) var id: UUID
    @Relationship var debtor: Debtor
    var title: String?
    var principal: Decimal
    var startDate: Date
    var installmentCount: Int
    var currencyCode: String
    var interestRateMonthly: Decimal?
    @Relationship(deleteRule: .cascade) var installments: [Installment]
    var closed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        debtor: Debtor,
        title: String? = nil,
        principal: Decimal,
        startDate: Date,
        installmentCount: Int,
        currencyCode: String = "BRL",
        interestRateMonthly: Decimal? = nil,
        closed: Bool = false,
        createdAt: Date = .now
    ) {
        precondition(principal > 0)
        precondition(installmentCount >= 1)
        self.id = id
        self.debtor = debtor
        self.title = title
        self.principal = principal
        self.startDate = startDate
        self.installmentCount = installmentCount
        self.currencyCode = currencyCode
        self.interestRateMonthly = interestRateMonthly
        self.installments = []
        self.closed = closed
        self.createdAt = createdAt
    }
}

enum InstallmentStatus: Int, Codable, Sendable {
    case pending, partial, paid, overdue
}

@Model final class Installment {
    @Attribute(.unique) var id: UUID
    @Relationship var agreement: DebtAgreement
    var number: Int
    var dueDate: Date
    var amount: Decimal
    var paidAmount: Decimal
    var statusRaw: Int
    @Relationship(deleteRule: .cascade) var payments: [Payment]

    var status: InstallmentStatus {
        get { InstallmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        agreement: DebtAgreement,
        number: Int,
        dueDate: Date,
        amount: Decimal,
        paidAmount: Decimal = .zero,
        status: InstallmentStatus = .pending
    ) {
        precondition(number >= 1)
        precondition(amount > 0)
        precondition(paidAmount >= 0)
        self.id = id
        self.agreement = agreement
        self.number = number
        self.dueDate = dueDate
        self.amount = amount
        self.paidAmount = paidAmount
        self.statusRaw = status.rawValue
        self.payments = []
    }
}

@Model final class Payment {
    @Attribute(.unique) var id: UUID
    @Relationship var installment: Installment
    var date: Date
    var amount: Decimal
    var methodRaw: String
    var note: String?

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        installment: Installment,
        date: Date,
        amount: Decimal,
        method: PaymentMethod,
        note: String? = nil
    ) {
        precondition(amount > 0)
        self.id = id
        self.installment = installment
        self.date = date
        self.amount = amount
        self.methodRaw = method.rawValue
        self.note = note
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Sendable {
    case pix, cash, transfer, other
}

@Model final class FixedExpense {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var category: String?
    var dueDay: Int
    var active: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: String? = nil,
        dueDay: Int,
        active: Bool = true
    ) {
        precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty)
        precondition(amount >= 0)
        precondition((1...31).contains(dueDay))
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.dueDay = dueDay
        self.active = active
    }
}

@Model final class SalarySnapshot {
    @Attribute(.unique) var id: UUID
    var referenceMonth: Date
    var amount: Decimal
    var note: String?

    init(id: UUID = UUID(), referenceMonth: Date, amount: Decimal, note: String? = nil) {
        precondition(amount >= 0)
        self.id = id
        self.referenceMonth = referenceMonth
        self.amount = amount
        self.note = note
    }
}

extension Installment {
    var remainingAmount: Decimal {
        (amount - paidAmount).clamped(to: .zero...amount)
    }

    var isOverdue: Bool {
        status == .overdue || (status != .paid && dueDate < .now)
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    func clamped(to range: ClosedRange<Decimal>) -> Decimal {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
