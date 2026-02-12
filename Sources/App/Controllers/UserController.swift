import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.get(":userID", use: showCurrent)
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
}
