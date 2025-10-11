import Foundation
import SwiftData

/// Centralized persistence operations helper that eliminates duplicated save/rollback/notification patterns.
/// Replaces ~15 lines of boilerplate code in every ViewModel operation with a single method call.
///
/// **Before (duplicated in every ViewModel):**
/// ```swift
/// do {
///     try context.save()
///     try load()
///     NotificationCenter.default.post(name: .financialDataDidChange, object: nil)
/// } catch {
///     context.rollback()
///     self.error = .persistence("error.generic")
/// }
/// ```
///
/// **After (using PersistenceHelper):**
/// ```swift
/// await context.saveWithNotification(
///     onSuccess: { try await self.load() },
///     onError: { self.error = .persistence("error.generic") }
/// )
/// ```
@MainActor
final class PersistenceHelper {

    // MARK: - Save with Automatic Rollback

    /// Saves the context with automatic rollback on error.
    /// Most basic operation - just save or rollback.
    ///
    /// - Parameter context: The ModelContext to save
    /// - Returns: Result indicating success or error
    @discardableResult
    static func save(_ context: ModelContext) -> Result<Void, Error> {
        do {
            try context.save()
            return .success(())
        } catch {
            context.rollback()
            return .failure(error)
        }
    }

    // MARK: - Save with Notification

    /// Saves context and posts notification on success, rolls back on error.
    /// Replaces the most common pattern in ViewModels.
    ///
    /// - Parameters:
    ///   - context: The ModelContext to save
    ///   - notification: Notification name to post (default: .financialDataDidChange)
    /// - Returns: Result indicating success or error
    @discardableResult
    static func saveWithNotification(
        _ context: ModelContext,
        notification: Notification.Name = .financialDataDidChange
    ) -> Result<Void, Error> {
        let result = save(context)

        if case .success = result {
            NotificationCenter.default.post(name: notification, object: nil)
        }

        return result
    }

    // MARK: - Save with Callbacks (Async)

    /// Saves context with async success/error callbacks.
    /// Perfect for ViewModels that need to reload data after save.
    ///
    /// Usage:
    /// ```swift
    /// await context.saveWithCallbacks(
    ///     onSuccess: { try await self.load() },
    ///     onError: { self.error = .persistence($0) }
    /// )
    /// ```
    static func saveWithCallbacks(
        _ context: ModelContext,
        notification: Notification.Name = .financialDataDidChange,
        onSuccess: @escaping () async throws -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        do {
            try context.save()
            NotificationCenter.default.post(name: notification, object: nil)
            try await onSuccess()
        } catch {
            context.rollback()
            onError(error)
        }
    }

    // MARK: - Save with Reload

    /// Saves context, posts notification, and executes a reload closure.
    /// Synchronous version for ViewModels with sync load methods.
    ///
    /// Usage:
    /// ```swift
    /// context.saveAndReload { try self.load() }
    ///     .mapError { self.error = .persistence($0) }
    /// ```
    @discardableResult
    static func saveAndReload(
        _ context: ModelContext,
        notification: Notification.Name = .financialDataDidChange,
        reload: () throws -> Void
    ) -> Result<Void, Error> {
        do {
            try context.save()
            NotificationCenter.default.post(name: notification, object: nil)
            try reload()
            return .success(())
        } catch {
            context.rollback()
            return .failure(error)
        }
    }
}

// MARK: - ModelContext Extension

extension ModelContext {
    /// Convenience method: Save with automatic rollback on error.
    @discardableResult
    @MainActor
    func saveOrRollback() -> Result<Void, Error> {
        PersistenceHelper.save(self)
    }

    /// Convenience method: Save with notification posting.
    @discardableResult
    @MainActor
    func saveWithNotification(_ notification: Notification.Name = .financialDataDidChange) -> Result<Void, Error> {
        PersistenceHelper.saveWithNotification(self, notification: notification)
    }

    /// Convenience method: Save with async callbacks.
    @MainActor
    func saveWithCallbacks(
        notification: Notification.Name = .financialDataDidChange,
        onSuccess: @escaping () async throws -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        await PersistenceHelper.saveWithCallbacks(
            self,
            notification: notification,
            onSuccess: onSuccess,
            onError: onError
        )
    }

    /// Convenience method: Save and reload synchronously.
    @discardableResult
    @MainActor
    func saveAndReload(
        notification: Notification.Name = .financialDataDidChange,
        reload: () throws -> Void
    ) -> Result<Void, Error> {
        PersistenceHelper.saveAndReload(self, notification: notification, reload: reload)
    }
}

// MARK: - Common Error Handling Patterns

extension Result where Success == Void, Failure == Error {
    /// Maps error to AppError.persistence and assigns to error binding.
    ///
    /// Usage:
    /// ```swift
    /// context.saveWithNotification()
    ///     .handlePersistenceError { self.error = $0 }
    /// ```
    func handlePersistenceError(
        message: String.LocalizationValue = "error.generic",
        assign: (AppError) -> Void
    ) {
        if case .failure = self {
            assign(.persistence(message))
        }
    }

    /// Throws AppError.persistence if operation failed.
    func orThrowPersistenceError(message: String.LocalizationValue = "error.generic") throws {
        if case .failure = self {
            throw AppError.persistence(message)
        }
    }
}

// MARK: - Batch Operations Helper

extension PersistenceHelper {
    /// Performs multiple operations in a transaction with automatic rollback.
    /// All operations succeed or all fail together.
    ///
    /// Usage:
    /// ```swift
    /// await PersistenceHelper.performBatch(context) { ctx in
    ///     ctx.insert(debtor)
    ///     debtor.agreements.append(agreement)
    ///     try await loadData()
    /// }
    /// ```
    static func performBatch(
        _ context: ModelContext,
        notification: Notification.Name = .financialDataDidChange,
        operations: () async throws -> Void
    ) async -> Result<Void, Error> {
        do {
            try await operations()
            try context.save()
            NotificationCenter.default.post(name: notification, object: nil)
            return .success(())
        } catch {
            context.rollback()
            return .failure(error)
        }
    }
}

// MARK: - Delete Operations

extension ModelContext {
    /// Deletes object and saves with notification, rolling back on error.
    ///
    /// Usage:
    /// ```swift
    /// context.deleteWithNotification(debtor)
    ///     .handlePersistenceError { self.error = $0 }
    /// ```
    @discardableResult
    @MainActor
    func deleteWithNotification<T: PersistentModel>(
        _ object: T,
        notification: Notification.Name = .financialDataDidChange
    ) -> Result<Void, Error> {
        self.delete(object)
        return saveWithNotification(notification)
    }

    /// Deletes multiple objects and saves with notification.
    @discardableResult
    @MainActor
    func deleteWithNotification<T: PersistentModel>(
        _ objects: [T],
        notification: Notification.Name = .financialDataDidChange
    ) -> Result<Void, Error> {
        objects.forEach { self.delete($0) }
        return saveWithNotification(notification)
    }
}

// MARK: - Testing Helpers

#if DEBUG
extension PersistenceHelper {
    /// Creates an in-memory ModelContext for testing.
    /// Never persists to disk.
    @MainActor
    static func createInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Debtor.self, DebtAgreement.self, Installment.self,
                 Payment.self, FixedExpense.self, SalarySnapshot.self,
                 CashTransaction.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
#endif
