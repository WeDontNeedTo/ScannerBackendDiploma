import Foundation

struct ItemCreateData {
    let number: String
    let name: String
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID
}

struct ItemUpdateData {
    let itemID: UUID
    let number: String?
    let name: String?
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID?
}

struct ItemSearchData {
    let query: String?
    let name: String?
    let number: String?
    let responsibleUserID: UUID?
    let page: Int?
    let per: Int?
}

struct ItemSetLocationData {
    let itemID: UUID
    let locationID: UUID
    let responsibleUserID: UUID?
}

struct ItemGrabData {
    let itemID: UUID
    let requestedToUserID: UUID?
}

struct ItemMoveToBrokenData {
    let itemID: UUID
    let locationID: UUID
    let quantity: Int
    let reason: String?
    let notes: String?
}

struct ItemJournalRecordData {
    let itemID: UUID
    let actorUserID: UUID?
    let eventType: String
    let message: String
}
