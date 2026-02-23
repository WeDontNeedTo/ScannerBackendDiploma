import Foundation
import Vapor

struct ItemScanResponse: Content {
    let item: ItemResponse
    let categoryName: String?
    let locations: [Location]
    let currentLocation: ItemCurrentLocationInfo?
    let isBroken: Bool
    let isGrabbed: Bool
    let grabbedBy: UserGrabInfo?
}

struct ItemResponse: Content {
    let id: UUID?
    let number: String
    let name: String
    let description: String?
    let priceRub: Decimal?
    let responsibleUser: ItemResponsibleUserResponse?
    let parameters: [ItemParameter]
}

struct ItemResponsibleUserResponse: Content {
    let id: UUID?
    let fullName: String
}

struct ItemCurrentLocationInfo: Content {
    let location: Location
}

struct UserGrabInfo: Content {
    let user: UserPublicResponse
    let name: String
    let grabbedAt: Date?
}

struct ItemResponsibleUserFilter: Content {
    let id: UUID?
    let fullName: String
}

struct ItemAvailableFiltersResponse: Content {
    let materiallyResponsiblePersons: [ItemResponsibleUserFilter]
}

struct ItemAvailableActionFlags: Content {
    let grabDirect: Bool
    let grabRequest: Bool
    let setLocationDirect: Bool
    let setLocationRequest: Bool
    let moveToBroken: Bool
    let returnItem: Bool
}

enum ItemAvailableAction: String, Content {
    case grabDirect = "grab_direct"
    case grabRequest = "grab_request"
    case setLocationDirect = "set_location_direct"
    case setLocationRequest = "set_location_request"
    case moveToBroken = "move_to_broken"
    case returnItem = "return_item"
}

struct ItemAvailableActionsResponse: Content {
    let itemID: UUID
    let currentUserID: UUID
    let currentUserRole: UserRole
    let materiallyResponsiblePersonID: UUID?
    let actions: ItemAvailableActionFlags
    let availableActions: [ItemAvailableAction]
}

struct ItemJournalMessageResponse: Content {
    let id: UUID?
    let createdAt: Date
    let message: String
}

struct ItemJournalPageResponse: Content {
    let messages: [ItemJournalMessageResponse]
    let page: Int
    let per: Int
    let total: Int
    let totalPages: Int
    let hasNext: Bool
}
