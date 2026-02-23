import Fluent
import Vapor

enum UserItemStatus: String, Codable, Content {
    case requested
    case transferRequested = "transfer_requested"
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
        case "transfer_requested", "transfer requested":
            self = .transferRequested
        case "approved":
            self = .approved
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported user item status value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

final class UserItem: Model, Content {
    static let schema = "user_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "item_id")
    var item: Item

    @Field(key: "status")
    var status: UserItemStatus

    @OptionalField(key: "approved_by_user_id")
    var approvedByUserID: UUID?

    @OptionalField(key: "requested_to_user_id")
    var requestedToUserID: UUID?

    @Timestamp(key: "grabbed_at", on: .create)
    var grabbedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        itemID: UUID,
        status: UserItemStatus = .requested,
        approvedByUserID: UUID? = nil,
        requestedToUserID: UUID? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.$item.id = itemID
        self.status = status
        self.approvedByUserID = approvedByUserID
        self.requestedToUserID = requestedToUserID
    }
}
