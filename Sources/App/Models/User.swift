import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "login")
    var login: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "full_name")
    var fullName: String

    @Field(key: "age")
    var age: Int

    @Field(key: "position")
    var position: String

    @OptionalChild(for: \.$user)
    var token: UserToken?

    @Children(for: \.$user)
    var grabbedItems: [UserItem]

    init() {}

    init(
        id: UUID? = nil,
        login: String,
        passwordHash: String,
        fullName: String,
        age: Int,
        position: String
    ) {
        self.id = id
        self.login = login
        self.passwordHash = passwordHash
        self.fullName = fullName
        self.age = age
        self.position = position
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$login
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: passwordHash)
    }
}

struct UserPublicResponse: Content {
    let id: UUID?
    let login: String
    let fullName: String
    let age: Int
    let position: String
}

extension User {
    func asPublic() -> UserPublicResponse {
        UserPublicResponse(
            id: id,
            login: login,
            fullName: fullName,
            age: age,
            position: position
        )
    }
}

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
