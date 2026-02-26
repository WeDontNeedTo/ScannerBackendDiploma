import Foundation
import Vapor

struct SettingsUsersQuery: Content {
    let page: Int?
    let per: Int?
}

struct SettingsUserRoleUpdateRequest: Content {
    let role: UserRole
}

struct SettingsUserItemsAddRequest: Content {
    let itemIDs: [UUID]
}

struct SettingsUserItemsRemoveRequest: Content {
    let itemIDs: [UUID]
    let reassignToUserID: UUID
}
