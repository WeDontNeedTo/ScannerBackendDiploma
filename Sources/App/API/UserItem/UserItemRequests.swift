import Foundation
import Vapor

struct CreateUserItemRequest: Content {
    let itemID: UUID
    let requestedToUserID: UUID?
}

struct UpdateUserItemRequest: Content {
}

struct ReturnUserItemRequest: Content {
    let itemID: UUID
}

struct TransferUserItemRequest: Content {
    let itemID: UUID
    let toUserID: UUID
}
