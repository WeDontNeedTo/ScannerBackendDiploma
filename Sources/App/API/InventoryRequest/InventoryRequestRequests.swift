import Foundation
import Vapor

struct CreateInventoryRequestDraftPayload: Content {
    let materiallyResponsibleUserID: UUID
    let inventoryDate: String
}

struct UpdateInventoryRequestItemsPayload: Content {
    let itemIDs: [UUID]
}

struct InventoryScanPayload: Content {
    let scannedItemID: UUID
}

struct InventoryMRPCompletePayload: Content {
    let outcome: InventoryRequestMRPCompleteOutcome
}
