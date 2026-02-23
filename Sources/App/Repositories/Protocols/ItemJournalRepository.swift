import Fluent
import Foundation

protocol ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent]
    func count(itemID: UUID, on db: Database) async throws -> Int
}
