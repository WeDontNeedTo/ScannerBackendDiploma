import Foundation
import Vapor

struct CreateItemRequest: Content {
    let number: String
    let name: String
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID
}

struct UpdateItemRequest: Content {
    let number: String?
    let name: String?
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID?
}

struct ItemSearchQuery: Content {
    let query: String?
    let name: String?
    let number: String?
    let responsibleUserID: UUID?
    let page: Int?
    let per: Int?
}

struct SetItemLocationRequest: Content {
    let locationID: UUID
    let responsibleUserID: UUID?
}

struct GrabItemRequest: Content {
    let requestedToUserID: UUID?
}

struct MoveItemToBrokenRequest: Content {
    let locationID: UUID
    let quantity: Int
    let reason: String?
    let notes: String?
}

struct ItemJournalQuery: Content {
    let page: Int?
    let per: Int?
}
