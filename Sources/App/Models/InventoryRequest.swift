import Fluent
import Foundation
import Vapor

enum InventoryRequestStatus: String, Codable, Content {
    case draft
    case submitted
    case mrpCompletedSuccess = "mrp_completed_success"
    case mrpCompletedMissing = "mrp_completed_missing"
    case finalizedSuccess = "finalized_success"
    case finalizedMissing = "finalized_missing"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "'\"")
                    .union(.whitespacesAndNewlines)
            )
            .lowercased()
        switch rawValue {
        case "draft":
            self = .draft
        case "submitted":
            self = .submitted
        case "mrp_completed_success", "mrp completed success":
            self = .mrpCompletedSuccess
        case "mrp_completed_missing", "mrp completed missing":
            self = .mrpCompletedMissing
        case "finalized_success", "finalized success":
            self = .finalizedSuccess
        case "finalized_missing", "finalized missing":
            self = .finalizedMissing
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported inventory request status value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

final class InventoryRequest: Model, Content {
    static let schema = "inventory_requests"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "requester_user_id")
    var requester: User

    @Parent(key: "materially_responsible_user_id")
    var materiallyResponsibleUser: User

    @Field(key: "inventory_date")
    var inventoryDate: Date

    @Field(key: "status")
    var status: InventoryRequestStatus

    @OptionalField(key: "submitted_at")
    var submittedAt: Date?

    @OptionalField(key: "mrp_completed_at")
    var mrpCompletedAt: Date?

    @OptionalField(key: "mrp_completed_by_user_id")
    var mrpCompletedByUserID: UUID?

    @OptionalField(key: "final_approved_at")
    var finalApprovedAt: Date?

    @OptionalField(key: "final_approved_by_user_id")
    var finalApprovedByUserID: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$request)
    var items: [InventoryRequestItem]

    init() {}

    init(
        id: UUID? = nil,
        requesterUserID: UUID,
        materiallyResponsibleUserID: UUID,
        inventoryDate: Date,
        status: InventoryRequestStatus = .draft
    ) {
        self.id = id
        self.$requester.id = requesterUserID
        self.$materiallyResponsibleUser.id = materiallyResponsibleUserID
        self.inventoryDate = inventoryDate
        self.status = status
    }
}
