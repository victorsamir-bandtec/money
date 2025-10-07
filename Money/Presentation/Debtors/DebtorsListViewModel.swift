import Foundation
import SwiftData
import Combine

@MainActor
final class DebtorsListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var debtors: [Debtor] = []
    @Published var showArchived: Bool = false
    @Published var error: AppError?
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var archivedCount: Int = 0

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load() throws {
        let shouldIncludeArchived = showArchived
        let predicate = #Predicate<Debtor> { debtor in
            shouldIncludeArchived || debtor.archived == false
        }
        let descriptor = FetchDescriptor<Debtor>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var results = try context.fetch(descriptor)

        let fullDescriptor = FetchDescriptor<Debtor>()
        let fullList = try context.fetch(fullDescriptor)
        totalCount = fullList.count
        archivedCount = fullList.filter(\.archived).count

        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            results = results.filter { debtor in
                debtor.name.localizedCaseInsensitiveContains(term)
            }
        }
        debtors = results
    }

    func addDebtor(name: String, phone: String?, note: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = .validation("error.debtor.name")
            return
        }
        let debtor = Debtor(name: trimmed, phone: phone, note: note)
        context.insert(debtor)
        do {
            try context.save()
            try load()
        } catch {
            context.delete(debtor)
            self.error = .persistence("error.generic")
        }
    }

    var activeCount: Int {
        max(totalCount - archivedCount, 0)
    }

    func toggleArchive(_ debtor: Debtor) {
        debtor.archived.toggle()
        do {
            try context.save()
            try load()
        } catch {
            context.undoManager?.undo()
            self.error = .persistence("error.generic")
        }
    }

    func deleteDebtor(_ debtor: Debtor) {
        context.delete(debtor)
        do {
            try context.save()
            try load()
            NotificationCenter.default.post(name: .debtorDataDidChange, object: nil)
            NotificationCenter.default.postFinanceDataUpdates(agreementChanged: true)
        } catch {
            context.rollback()
            self.error = .persistence("error.generic")
        }
    }
}
