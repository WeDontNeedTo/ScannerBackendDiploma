import Fluent
import Vapor

enum LocationKind: String, Codable {
    case warehouse
    case office
}

final class Location: Model, Content {
    static let schema = "locations"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "kind")
    var kind: LocationKind

    @OptionalField(key: "address")
    var address: String?

    @OptionalField(key: "shelf")
    var shelf: String?

    @OptionalField(key: "row")
    var row: String?

    @OptionalField(key: "section")
    var section: String?

    @Children(for: \.$location)
    var items: [ItemLocation]

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        kind: LocationKind,
        address: String? = nil,
        shelf: String? = nil,
        row: String? = nil,
        section: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.address = address
        self.shelf = shelf
        self.row = row
        self.section = section
    }
}

struct CreateLocation: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Location.schema)
            .id()
            .field("name", .string, .required)
            .field("kind", .string, .required)
            .field("address", .string)
            .field("shelf", .string)
            .field("row", .string)
            .field("section", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Location.schema).delete()
    }
}
