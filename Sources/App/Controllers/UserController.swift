import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.get(":userID", use: showCurrent)
        users.put(":userID", "role", use: updateRole)
    }

    func showCurrent(req: Request) async throws -> UserPublicResponse {
        do {
            let userID = try req.requireUUID("userID")
            let response = try await req.application.services.userService.showCurrent(
                requestedUserID: userID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "users", entityID: userID)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func updateRole(req: Request) async throws -> UserPublicResponse {
        do {
            let userID = try req.requireUUID("userID")
            let payload = try req.content.decode(UpdateUserRoleRequest.self)
            let response = try await req.application.services.userService.updateRole(
                userID: userID,
                role: payload.role,
                context: context(req)
            )
            try await req.audit(
                action: "update",
                entity: "users",
                entityID: userID,
                message: "role=\(payload.role.rawValue)"
            )
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}

struct UpdateUserRoleRequest: Content {
    let role: UserRole
}
