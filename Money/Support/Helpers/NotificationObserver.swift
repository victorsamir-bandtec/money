import Foundation
import Combine

/// Type-safe notification observer with automatic cleanup.
/// Eliminates manual observer management and memory leaks.
///
/// **Before (manual management):**
/// ```swift
/// private var notificationObservers: [Any] = []
///
/// func setupNotificationObservers() {
///     let observer = NotificationCenter.default.addObserver(
///         forName: .financialDataDidChange,
///         object: nil,
///         queue: .main
///     ) { [weak self] _ in
///         self?.handleDataChange()
///     }
///     notificationObservers.append(observer)
/// }
///
/// deinit {
///     notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
/// }
/// ```
///
/// **After (using NotificationObserver):**
/// ```swift
/// private let dataChangeObserver = NotificationObserver(.financialDataDidChange)
///
/// init() {
///     dataChangeObserver.observe { [weak self] in
///         self?.handleDataChange()
///     }
/// }
/// // Auto-cleanup on deinit!
/// ```
@MainActor
final class NotificationObserver {
    fileprivate let notificationName: Notification.Name
    private var cancellable: AnyCancellable?
    private let center: NotificationCenter

    /// Creates a notification observer for the specified notification name.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - center: The notification center (default: .default)
    init(
        _ name: Notification.Name,
        center: NotificationCenter = .default
    ) {
        self.notificationName = name
        self.center = center
    }

    /// Starts observing the notification and calls the handler when received.
    ///
    /// - Parameter handler: Closure called when notification is posted
    func observe(handler: @escaping () -> Void) {
        cancellable = center.publisher(for: notificationName)
            .receive(on: DispatchQueue.main)
            .sink { _ in handler() }
    }

    /// Starts observing with access to the notification object.
    ///
    /// - Parameter handler: Closure called with the notification
    func observe(handler: @escaping (Notification) -> Void) {
        cancellable = center.publisher(for: notificationName)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
    }

    /// Stops observing the notification.
    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }

    nonisolated deinit {
        // Cancellable cleanup happens automatically
    }
}

// MARK: - Multiple Observers Manager

/// Manages multiple notification observers with automatic cleanup.
/// Perfect for ViewModels that observe multiple notifications.
///
/// Usage:
/// ```swift
/// private let observers = NotificationObservers()
///
/// init() {
///     observers.observe(.financialDataDidChange) { [weak self] in
///         self?.handleDataChange()
///     }
///
///     observers.observe(.expenseUpdated) { [weak self] in
///         self?.handleExpenseUpdate()
///     }
/// }
/// ```
@MainActor
final class NotificationObservers {
    private var observers: [NotificationObserver] = []

    /// Adds an observer for the specified notification.
    func observe(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        handler: @escaping () -> Void
    ) {
        let observer = NotificationObserver(name, center: center)
        observer.observe(handler: handler)
        observers.append(observer)
    }

    /// Adds an observer with access to the notification object.
    func observe(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        handler: @escaping (Notification) -> Void
    ) {
        let observer = NotificationObserver(name, center: center)
        observer.observe(handler: handler)
        observers.append(observer)
    }

    /// Cancels all observers.
    func cancelAll() {
        observers.forEach { $0.cancel() }
        observers.removeAll()
    }

    nonisolated deinit {
        // Observers cleanup happens automatically
    }
}

// MARK: - Combine-based Notification Publisher Extensions

extension NotificationCenter {
    /// Creates a publisher that emits when any of the specified notifications are posted.
    ///
    /// Usage:
    /// ```swift
    /// NotificationCenter.default.publisher(for: [.financialDataDidChange, .expenseUpdated])
    ///     .sink { self.reload() }
    ///     .store(in: &cancellables)
    /// ```
    func publisher(for names: [Notification.Name]) -> AnyPublisher<Notification, Never> {
        let publishers = names.map { publisher(for: $0) }
        return Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
}

// MARK: - Common Notification Names

extension Notification.Name {
    // Note: .financialDataDidChange is already defined in ModelContextNotifications.swift

    /// Posted when expenses are updated
    static let expensesDidChange = Notification.Name("expensesDidChange")

    /// Posted when debtors are updated
    static let debtorsDidChange = Notification.Name("debtorsDidChange")

    /// Posted when agreements are updated
    static let agreementsDidChange = Notification.Name("agreementsDidChange")

    /// Posted when salary is updated
    static let salaryDidChange = Notification.Name("salaryDidChange")
}

// MARK: - Type-Safe Notification Posting

extension NotificationCenter {
    /// Posts a notification on the main thread.
    /// Ensures UI updates happen on main thread.
    @MainActor
    func postOnMain(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        if Thread.isMainThread {
            post(name: name, object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                self.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }
}

// MARK: - Async/Await Notification Waiting

extension NotificationCenter {
    /// Waits for a notification to be posted.
    /// Useful for testing or coordinating async operations.
    ///
    /// Usage:
    /// ```swift
    /// Task {
    ///     await NotificationCenter.default.waitForNotification(.financialDataDidChange)
    ///     print("Data changed!")
    /// }
    /// ```
    func waitForNotification(
        _ name: Notification.Name,
        timeout: TimeInterval = 10
    ) async throws {
        final class ObserverToken: @unchecked Sendable {
            var observer: NSObjectProtocol?
            var timeoutItem: DispatchWorkItem?
            var didComplete = false
        }

        let token = ObserverToken()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let timeoutItem = DispatchWorkItem {
                guard !token.didComplete else { return }
                token.didComplete = true
                if let observer = token.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(throwing: NotificationTimeoutError())
            }
            token.timeoutItem = timeoutItem

            token.observer = addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                guard !token.didComplete else { return }
                token.didComplete = true
                if let observer = token.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                token.timeoutItem?.cancel()
                continuation.resume()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        }
    }
}

struct NotificationTimeoutError: Error {
    let message = "Notification wait timed out"
}

// MARK: - Debounced Observer

/// Observer that debounces rapid notification posting.
/// Useful for expensive operations triggered by frequent updates.
///
/// Usage:
/// ```swift
/// let debouncedObserver = DebouncedNotificationObserver(
///     .financialDataDidChange,
///     debounceInterval: 0.5
/// )
///
/// debouncedObserver.observe { [weak self] in
///     // This will only fire once every 0.5 seconds max
///     self?.expensiveReload()
/// }
/// ```
@MainActor
final class DebouncedNotificationObserver {
    private let observer: NotificationObserver
    private var cancellable: AnyCancellable?
    private let debounceInterval: TimeInterval

    init(
        _ name: Notification.Name,
        debounceInterval: TimeInterval = 0.3,
        center: NotificationCenter = .default
    ) {
        self.observer = NotificationObserver(name, center: center)
        self.debounceInterval = debounceInterval
    }

    func observe(handler: @escaping () -> Void) {
        cancellable = NotificationCenter.default.publisher(for: observer.notificationName)
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { _ in handler() }
    }

    func cancel() {
        cancellable?.cancel()
        observer.cancel()
    }

    nonisolated deinit {
        // Cleanup happens automatically
    }
}

#if DEBUG
// MARK: - Testing Helpers

extension NotificationCenter {
    /// Posts a notification and waits for observers to process it.
    /// Useful for testing.
    @MainActor
    func postAndWait(
        name: Notification.Name,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) async {
        post(name: name, object: object, userInfo: userInfo)
        // Give observers time to react
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
}
#endif
