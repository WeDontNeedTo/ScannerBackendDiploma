import Fluent
import Foundation
import Vapor

enum InventoryRequestItemStatus: String, Codable, Content {
    case pending
    case found
    case missing

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "'\"")
                    .union(.whitespacesAndNewlines)
            )
            .lowercased()
        switch rawValue {
        case "pending":
            self = .pending
        case "found":
            self = .found
        case "missing":
            self = .missing
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported inventory request item status value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

final class InventoryRequestItem: Model, Content {
    static let schema = "inventory_request_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "request_id")
    var request: InventoryRequest

    @Parent(key: "item_id")
    var item: Item

    @Field(key: "item_number_snapshot")
    var itemNumberSnapshot: String

    @Field(key: "item_name_snapshot")
    var itemNameSnapshot: String

    @Field(key: "status")
    var status: InventoryRequestItemStatus

    @OptionalField(key: "scanned_at")
    var scannedAt: Date?

    @OptionalField(key: "scanned_by_user_id")
    var scannedByUserID: UUID?

    @OptionalField(key: "scanned_item_id")
    var scannedItemID: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        requestID: UUID,
        itemID: UUID,
        itemNumberSnapshot: String,
        itemNameSnapshot: String,
        status: InventoryRequestItemStatus = .pending,
        scannedAt: Date? = nil,
        scannedByUserID: UUID? = nil,
        scannedItemID: UUID? = nil
    ) {
        self.id = id
        self.$request.id = requestID
        self.$item.id = itemID
        self.itemNumberSnapshot = itemNumberSnapshot
        self.itemNameSnapshot = itemNameSnapshot
        self.status = status
        self.scannedAt = scannedAt
        self.scannedByUserID = scannedByUserID
        self.scannedItemID = scannedItemID
    }
}
