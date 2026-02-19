import Foundation

enum DomainEvent: Sendable {
    case debtorChanged
    case agreementChanged
    case paymentChanged
    case salaryChanged
    case transactionChanged
}

protocol DomainEventPublishing: Sendable {
    func publish(_ event: DomainEvent) async
}

protocol DomainEventSubscribing: Sendable {
    func stream() async -> AsyncStream<DomainEvent>
}

actor DomainEventBus: DomainEventPublishing, DomainEventSubscribing {
    private var continuations: [UUID: AsyncStream<DomainEvent>.Continuation] = [:]

    func publish(_ event: DomainEvent) async {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func stream() async -> AsyncStream<DomainEvent> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
