import Fluent
import Vapor

enum ItemLocationRequestStatus: String, Codable, Content {
    case requested
    case approved

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "'\"")
                    .union(.whitespacesAndNewlines)
            )
            .lowercased()
        switch rawValue {
        case "requested":
            self = .requested
        case "approved":
            self = .approved
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported item location request status value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

final class ItemLocationRequest: Model, Content {
    static let schema = "item_location_requests"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "item_id")
    var item: Item

    @Parent(key: "location_id")
    var location: Location

    @Parent(key: "requester_user_id")
    var requester: User

    @OptionalField(key: "requested_to_user_id")
    var requestedToUserID: UUID?

    @OptionalField(key: "approved_by_user_id")
    var approvedByUserID: UUID?

    @Field(key: "status")
    var status: ItemLocationRequestStatus

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        itemID: UUID,
        locationID: UUID,
        requesterUserID: UUID,
        requestedToUserID: UUID?,
        approvedByUserID: UUID? = nil,
        status: ItemLocationRequestStatus = .requested
    ) {
        self.id = id
        self.$item.id = itemID
        self.$location.id = locationID
        self.$requester.id = requesterUserID
        self.requestedToUserID = requestedToUserID
        self.approvedByUserID = approvedByUserID
        self.status = status
    }
}
