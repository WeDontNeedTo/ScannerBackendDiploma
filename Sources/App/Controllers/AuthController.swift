import Fluent
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        let protected = auth.grouped(UserToken.authenticator(), User.guardMiddleware())
        protected.post("logout", use: logout)
    }

    func register(req: Request) async throws -> AuthResponse {
        let payload = try req.content.decode(RegisterRequest.self)
        let existing = try await User.query(on: req.db)
            .filter(\.$login == payload.login)
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "Login is already in use.")
        }
        let passwordHash = try Bcrypt.hash(payload.password)
        let user = User(
            login: payload.login,
            passwordHash: passwordHash,
            fullName: payload.fullName,
            age: payload.age,
            position: payload.position,
            role: .employee
        )
        try await user.save(on: req.db)
        let token = try await issueToken(for: user, on: req.db)
        return AuthResponse(user: user.asPublic(), token: token.value)
    }

    func login(req: Request) async throws -> AuthResponse {
        let payload = try req.content.decode(LoginRequest.self)
         guard let user = try await User.query(on: req.db)
             .filter(\.$login == payload.login)
             .first() else {
             throw Abort(.unauthorized, reason: "Invalid credentials.")
         }
         guard try user.verify(password: payload.password) else {
             throw Abort(.unauthorized, reason: "Invalid credentials.")
         }
         let token = try await issueToken(for: user, on: req.db)
        return AuthResponse(user: user.asPublic(), token: token.value)
    }

    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .delete()
        try await req.audit(action: "logout", entity: "users", entityID: user.id)
        return .noContent
    }

    private func issueToken(for user: User, on db: Database) async throws -> UserToken {
        try await UserToken.query(on: db)
            .filter(\.$user.$id == user.requireID())
            .delete()
        let tokenValue = UUID().uuidString
        let token = UserToken(value: tokenValue, userID: try user.requireID())
        try await token.save(on: db)
        return token
    }
}

struct RegisterRequest: Content {
    let login: String
    let password: String
    let fullName: String
    let age: Int
    let position: String
}

struct LoginRequest: Content {
    let login: String
    let password: String
}

struct AuthResponse: Content {
    let user: UserPublicResponse
    let token: String
}
