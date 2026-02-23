import Foundation

struct UserItemCreateData {
    let itemID: UUID
    let requestedToUserID: UUID?
}

struct UserItemApproveData {
    let userItemID: UUID
}

struct UserItemUpdateData {
    let userItemID: UUID
}

struct UserItemDeleteData {
    let userItemID: UUID
}

struct UserItemReturnData {
    let itemID: UUID
}

struct UserItemTransferData {
    let itemID: UUID
    let toUserID: UUID
}
