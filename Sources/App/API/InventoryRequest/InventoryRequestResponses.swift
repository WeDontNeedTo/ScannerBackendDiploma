import Foundation
import Vapor

struct InventoryRequestItemResponse: Content {
    let id: UUID?
    let itemID: UUID
    let itemNumber: String
    let itemName: String
    let status: InventoryRequestItemStatus
    let scannedAt: Date?
    let scannedByUserID: UUID?
    let scannedItemID: UUID?
}

struct InventoryRequestResponse: Content {
    let id: UUID?
    let requesterUserID: UUID
    let materiallyResponsibleUserID: UUID
    let inventoryDate: String
    let status: InventoryRequestStatus
    let submittedAt: Date?
    let mrpCompletedAt: Date?
    let mrpCompletedByUserID: UUID?
    let finalApprovedAt: Date?
    let finalApprovedByUserID: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    let items: [InventoryRequestItemResponse]
}
