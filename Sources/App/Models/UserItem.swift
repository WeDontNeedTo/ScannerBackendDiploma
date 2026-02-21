import Fluent
import Vapor

enum UserItemStatus: String, Codable, Content {
    case requested
    case transferRequested = "transfer_requested"
    case approved
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

struct CreateUserItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .id()
            .field(
                "user_id",
                .uuid,
                .required,
                .references(User.schema, "id", onDelete: .cascade)
            )
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .restrict)
            )
            .field("grabbed_at", .datetime)
            .unique(on: "item_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema).delete()
    }
}

struct RemoveUserItemQuantity: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .deleteField("quantity")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .field("quantity", .int, .required)
            .update()
    }
}

struct AddUserItemRequestWorkflow: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .field("status", .string, .required, .sql(.default("'approved'")))
            .field(
                "approved_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field(
                "requested_to_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .deleteField("requested_to_user_id")
            .deleteField("approved_by_user_id")
            .deleteField("status")
            .update()
    }
}

struct AddUserItemRequestedToUserField: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .field(
                "requested_to_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .deleteField("requested_to_user_id")
            .update()
    }
}
