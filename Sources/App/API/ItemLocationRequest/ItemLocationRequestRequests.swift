import Foundation
import Vapor

struct CreateItemLocationRequestPayload: Content {
    let locationID: UUID
    let requestedToUserID: UUID?
}
