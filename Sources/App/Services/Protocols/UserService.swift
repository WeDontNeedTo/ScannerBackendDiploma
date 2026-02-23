import Foundation

protocol UserService {
    func showCurrent(requestedUserID: UUID, context: ServiceContext) async throws -> UserPublicResponse
    func updateRole(userID: UUID, role: UserRole, context: ServiceContext) async throws -> UserPublicResponse
}
