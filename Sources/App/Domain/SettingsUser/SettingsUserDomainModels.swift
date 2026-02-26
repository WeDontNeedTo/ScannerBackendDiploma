import Foundation

struct SettingsUsersListData {
    let page: Int?
    let per: Int?
}

struct SettingsUserRoleUpdateData {
    let userID: UUID
    let role: UserRole
}

struct SettingsUserItemsAddData {
    let userID: UUID
    let itemIDs: [UUID]
}

struct SettingsUserItemsRemoveData {
    let userID: UUID
    let itemIDs: [UUID]
    let reassignToUserID: UUID
}
