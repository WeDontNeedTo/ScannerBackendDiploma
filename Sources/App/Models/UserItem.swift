import Fluent
import Vapor

final class UserItem: Model, Content {
    static let schema = "user_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "item_id")
    var item: Item

    @Timestamp(key: "grabbed_at", on: .create)
    var grabbedAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, itemID: UUID) {
        self.id = id
        self.$user.id = userID
        self.$item.id = itemID
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
