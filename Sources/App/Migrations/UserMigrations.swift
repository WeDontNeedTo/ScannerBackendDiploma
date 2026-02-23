import Fluent

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .id()
            .field("login", .string, .required)
            .field("password_hash", .string, .required)
            .field("full_name", .string, .required)
            .field("age", .int, .required)
            .field("position", .string, .required)
            .unique(on: "login")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}

struct AddUserRoleField: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .field("role", .string, .required, .sql(.default("'employee'")))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .deleteField("role")
            .update()
    }
}
