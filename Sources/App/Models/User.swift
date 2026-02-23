import Fluent
import Vapor

enum UserRole: String, Codable, Content {
    case employee
    case materiallyResponsiblePerson = "materially_responsible_person"
    case accountant
    case admin

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "'\"")
                    .union(.whitespacesAndNewlines)
            )
            .lowercased()
        switch rawValue {
        case "employee":
            self = .employee
        case "materially_responsible_person", "materially responsible person", "mrp":
            self = .materiallyResponsiblePerson
        case "accountant":
            self = .accountant
        case "admin":
            self = .admin
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported role value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

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

    @Field(key: "role")
    var role: UserRole

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
        position: String,
        role: UserRole = .employee
    ) {
        self.id = id
        self.login = login
        self.passwordHash = passwordHash
        self.fullName = fullName
        self.age = age
        self.position = position
        self.role = role
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
    let role: UserRole
}

extension User {
    func asPublic() -> UserPublicResponse {
        UserPublicResponse(
            id: id,
            login: login,
            fullName: fullName,
            age: age,
            position: position,
            role: role
        )
    }

    var canManageInventory: Bool {
        role == .materiallyResponsiblePerson || role == .accountant || role == .admin
    }

    var canBypassRequestFlow: Bool {
        role == .accountant || role == .admin
    }

    var canApproveGrabRequests: Bool {
        canManageInventory
    }

    func requireInventoryManagerRole() throws {
        guard canManageInventory else {
            throw Abort(
                .forbidden,
                reason: "This action requires materially responsible person, accountant, or admin role."
            )
        }
    }

    func requireAdminRole() throws {
        guard role == .admin else {
            throw Abort(.forbidden, reason: "This action requires admin role.")
        }
    }
}
