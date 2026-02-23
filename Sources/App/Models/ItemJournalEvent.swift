import Fluent
import Foundation
import Vapor

final class ItemJournalEvent: Model, Content {
    static let schema = "item_journal_events"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "item_id")
    var item: Item

    @OptionalParent(key: "actor_user_id")
    var actorUser: User?

    @Field(key: "event_type")
    var eventType: String

    @Field(key: "message")
    var message: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        itemID: UUID,
        actorUserID: UUID? = nil,
        eventType: String,
        message: String
    ) {
        self.id = id
        self.$item.id = itemID
        self.$actorUser.id = actorUserID
        self.eventType = eventType
        self.message = message
    }
}
