import Foundation

struct DefaultUserService: UserService {
    private let userRepository: any UserRepository

    init(repositories: RepositoryContainer) {
        self.userRepository = repositories.userRepository
    }

    func showCurrent(requestedUserID: UUID, context: ServiceContext) async throws -> UserPublicResponse {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        guard try user.requireID() == requestedUserID else {
            throw DomainError.forbidden("You can only access your own user profile.")
        }
        return user.asPublic()
    }

    func updateRole(userID: UUID, role: UserRole, context: ServiceContext) async throws -> UserPublicResponse {
        guard let actor = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        guard actor.role == .admin else {
            throw DomainError.forbidden("This action requires admin role.")
        }
        guard let user = try await userRepository.find(id: userID, on: context.db) else {
            throw DomainError.notFound("User not found.")
        }
        user.role = role
        try await userRepository.save(user, on: context.db)
        return user.asPublic()
    }
}
