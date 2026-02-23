import Foundation

protocol ItemJournalService {
    func list(itemID: UUID, page: Int?, per: Int?, context: ServiceContext) async throws -> ItemJournalPageResponse
    func record(data: ItemJournalRecordData, context: ServiceContext) async throws
}
