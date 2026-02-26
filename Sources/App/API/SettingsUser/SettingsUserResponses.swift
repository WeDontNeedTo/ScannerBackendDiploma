import Foundation
import Vapor

struct SettingsUserRowResponse: Content {
    let user: UserPublicResponse
    let assignedItems: [Item]
}

struct SettingsUsersPageResponse: Content {
    let users: [SettingsUserRowResponse]
    let page: Int
    let per: Int
    let total: Int
    let totalPages: Int
    let hasNext: Bool
}

struct SettingsUserItemsOperationResponse: Content {
    let userID: UUID
    let items: [Item]
}
