import Foundation

enum InventoryRequestMRPCompleteOutcome: String, Codable {
    case success
    case missing
}

struct InventoryRequestCreateDraftData {
    let materiallyResponsibleUserID: UUID
    let inventoryDate: String
}

struct InventoryRequestSetItemsData {
    let requestID: UUID
    let itemIDs: [UUID]
}

struct InventoryRequestSubmitData {
    let requestID: UUID
}

struct InventoryRequestScanData {
    let requestID: UUID
    let itemID: UUID
    let scannedItemID: UUID
}

struct InventoryRequestMRPCompleteData {
    let requestID: UUID
    let outcome: InventoryRequestMRPCompleteOutcome
}

struct InventoryRequestFinalApproveData {
    let requestID: UUID
}
