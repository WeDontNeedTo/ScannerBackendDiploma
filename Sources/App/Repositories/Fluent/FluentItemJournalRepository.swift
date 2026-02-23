import Fluent
import Foundation

struct FluentItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {
        try await event.save(on: db)
    }

    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] {
        try await ItemJournalEvent.query(on: db)
            .filter(\.$item.$id == itemID)
            .sort(\.$createdAt, .descending)
            .sort(\.$id, .descending)
            .range(offset..<(offset + limit))
            .all()
    }

    func count(itemID: UUID, on db: Database) async throws -> Int {
        try await ItemJournalEvent.query(on: db)
            .filter(\.$item.$id == itemID)
            .count()
    }
}
