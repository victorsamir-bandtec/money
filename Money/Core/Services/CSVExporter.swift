import Foundation
import SwiftData

struct CSVExporter {
    enum ExportError: Error {
        case failedToWrite
    }

    func export(from context: ModelContext) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoneyExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try writeDebtors(to: directory.appendingPathComponent("devedores.csv"), context: context)
        try writeAgreements(to: directory.appendingPathComponent("acordos.csv"), context: context)
        try writeInstallments(to: directory.appendingPathComponent("parcelas.csv"), context: context)
        try writePayments(to: directory.appendingPathComponent("pagamentos.csv"), context: context)
        try writeExpenses(to: directory.appendingPathComponent("despesas.csv"), context: context)
        try writeTransactions(to: directory.appendingPathComponent("transacoes.csv"), context: context)

        return directory
    }

    private func writeDebtors(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Debtor>())
        var csv = "id;name;phone;note;createdAt;archived\n"
        for item in items {
            csv.append("\(item.id);\(item.name);\(item.phone ?? "");\(item.note ?? "");\(iso8601String(item.createdAt));\(item.archived)\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeAgreements(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<DebtAgreement>())
        var csv = "id;debtorId;title;principal;startDate;installmentCount;currencyCode;interestRateMonthly;closed\n"
        for item in items {
            csv.append("\(item.id);\(item.debtor.id);\(item.title ?? "");\(item.principal);\(iso8601String(item.startDate));\(item.installmentCount);\(item.currencyCode);\(item.interestRateMonthly ?? 0);\(item.closed)\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeInstallments(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Installment>())
        var csv = "id;agreementId;number;dueDate;amount;paidAmount;status\n"
        for item in items {
            csv.append("\(item.id);\(item.agreement.id);\(item.number);\(iso8601String(item.dueDate));\(item.amount);\(item.paidAmount);\(item.status.rawValue)\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writePayments(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Payment>())
        var csv = "id;installmentId;date;amount;method;note\n"
        for item in items {
            csv.append("\(item.id);\(item.installment.id);\(iso8601String(item.date));\(item.amount);\(item.method.rawValue);\(item.note ?? "")\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeExpenses(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<FixedExpense>())
        var csv = "id;name;amount;category;dueDay;active\n"
        for item in items {
            csv.append("\(item.id);\(item.name);\(item.amount);\(item.category ?? "");\(item.dueDay);\(item.active)\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeTransactions(to url: URL, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<CashTransaction>())
        var csv = "id;date;amount;type;category;note;createdAt\n"
        for item in items {
            csv.append("\(item.id);\(iso8601String(item.date));\(item.amount);\(item.type.rawValue);\(item.category ?? "");\(item.note ?? "");\(iso8601String(item.createdAt))\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
