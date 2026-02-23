import Fluent

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
