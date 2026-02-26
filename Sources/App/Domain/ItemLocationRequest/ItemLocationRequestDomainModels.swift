import Foundation

struct ItemLocationRequestCreateData {
    let itemID: UUID
    let locationID: UUID
    let requestedToUserID: UUID?
}

struct ItemLocationRequestApproveData {
    let requestID: UUID
}
