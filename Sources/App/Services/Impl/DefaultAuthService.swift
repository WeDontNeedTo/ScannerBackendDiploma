import Fluent
import Foundation
import Vapor

struct DefaultAuthService: AuthService {
    private let userRepository: any UserRepository
    private let userTokenRepository: any UserTokenRepository

    init(repositories: RepositoryContainer) {
        self.userRepository = repositories.userRepository
        self.userTokenRepository = repositories.userTokenRepository
    }

    func register(payload: RegisterRequest, context: ServiceContext) async throws -> AuthResponse {
        let existing = try await userRepository.findByLogin(payload.login, on: context.db)
        guard existing == nil else {
            throw DomainError.conflict("Login is already in use.")
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
        try await userRepository.save(user, on: context.db)

        let token = try await issueToken(for: user, on: context.db)
        return AuthResponse(user: user.asPublic(), token: token.value)
    }

    func login(payload: LoginRequest, context: ServiceContext) async throws -> AuthResponse {
        guard let user = try await userRepository.findByLogin(payload.login, on: context.db) else {
            throw DomainError.unauthorized("Invalid credentials.")
        }
        guard try user.verify(password: payload.password) else {
            throw DomainError.unauthorized("Invalid credentials.")
        }

        let token = try await issueToken(for: user, on: context.db)
        return AuthResponse(user: user.asPublic(), token: token.value)
    }

    func logout(context: ServiceContext) async throws -> UUID? {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        let userID = try user.requireID()
        try await userTokenRepository.deleteByUserID(userID, on: context.db)
        return user.id
    }
}

extension DefaultAuthService {
    private func issueToken(for user: User, on db: Database) async throws -> UserToken {
        let userID = try user.requireID()
        try await userTokenRepository.deleteByUserID(userID, on: db)
        let token = UserToken(value: UUID().uuidString, userID: userID)
        try await userTokenRepository.save(token, on: db)
        return token
    }
}
