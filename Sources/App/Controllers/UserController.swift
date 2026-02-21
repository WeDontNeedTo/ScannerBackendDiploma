import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.get(":userID", use: showCurrent)
        users.put(":userID", "role", use: updateRole)
    }

    func showCurrent(req: Request) async throws -> UserPublicResponse {
        let user = try req.auth.require(User.self)
        let userID = try req.requireUUID("userID")
        guard try user.requireID() == userID else {
            throw Abort(.forbidden, reason: "You can only access your own user profile.")
        }
        try await req.audit(action: "read", entity: "users", entityID: userID)
        return user.asPublic()
    }

    func updateRole(req: Request) async throws -> UserPublicResponse {
        let actor = try req.auth.require(User.self)
        try actor.requireAdminRole()
        let userID = try req.requireUUID("userID")
        let payload = try req.content.decode(UpdateUserRoleRequest.self)
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found.")
        }
        user.role = payload.role
        try await user.save(on: req.db)
        try await req.audit(
            action: "update",
            entity: "users",
            entityID: userID,
            message: "role=\(payload.role.rawValue)"
        )
        return user.asPublic()
    }
}

struct UpdateUserRoleRequest: Content {
    let role: UserRole
}
