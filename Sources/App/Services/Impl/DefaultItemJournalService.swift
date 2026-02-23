import Foundation

struct DefaultItemJournalService: ItemJournalService {
    private let itemRepository: any ItemRepository
    private let itemJournalRepository: any ItemJournalRepository

    private let defaultPer = 20
    private let maxPer = 100

    init(repositories: RepositoryContainer) {
        self.itemRepository = repositories.itemRepository
        self.itemJournalRepository = repositories.itemJournalRepository
    }

    func list(itemID: UUID, page: Int?, per: Int?, context: ServiceContext) async throws -> ItemJournalPageResponse {
        guard (try await itemRepository.find(id: itemID, on: context.db)) != nil else {
            throw DomainError.notFound("Item not found.")
        }

        let requestedPage = page ?? 1
        guard requestedPage > 0 else {
            throw DomainError.badRequest("Page must be greater than zero.")
        }

        let requestedPer = per ?? defaultPer
        guard requestedPer > 0 else {
            throw DomainError.badRequest("Per must be greater than zero.")
        }
        let normalizedPer = min(requestedPer, maxPer)

        let total = try await itemJournalRepository.count(itemID: itemID, on: context.db)
        let totalPages = max(1, Int(ceil(Double(total) / Double(normalizedPer))))
        let normalizedPage = min(requestedPage, totalPages)
        let offset = (normalizedPage - 1) * normalizedPer

        let events = try await itemJournalRepository.list(
            itemID: itemID,
            offset: offset,
            limit: normalizedPer,
            on: context.db
        )

        let messages = events.map { event in
            ItemJournalMessageResponse(
                id: event.id,
                createdAt: event.createdAt ?? Date.distantPast,
                message: event.message
            )
        }

        return ItemJournalPageResponse(
            messages: messages,
            page: normalizedPage,
            per: normalizedPer,
            total: total,
            totalPages: totalPages,
            hasNext: normalizedPage < totalPages
        )
    }

    func record(data: ItemJournalRecordData, context: ServiceContext) async throws {
        let event = ItemJournalEvent(
            itemID: data.itemID,
            actorUserID: data.actorUserID,
            eventType: data.eventType,
            message: data.message
        )
        try await itemJournalRepository.create(event, on: context.db)
    }
}
