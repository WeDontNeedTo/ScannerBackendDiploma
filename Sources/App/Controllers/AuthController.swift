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
        do {
            let payload = try req.content.decode(RegisterRequest.self)
            return try await req.application.services.authService.register(
                payload: payload,
                context: context(req)
            )
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func login(req: Request) async throws -> AuthResponse {
        do {
            let payload = try req.content.decode(LoginRequest.self)
            return try await req.application.services.authService.login(
                payload: payload,
                context: context(req)
            )
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func logout(req: Request) async throws -> HTTPStatus {
        do {
            let userID = try await req.application.services.authService.logout(context: context(req))
            try await req.audit(action: "logout", entity: "users", entityID: userID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
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
