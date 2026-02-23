import Foundation

protocol AuthService {
    func register(payload: RegisterRequest, context: ServiceContext) async throws -> AuthResponse
    func login(payload: LoginRequest, context: ServiceContext) async throws -> AuthResponse
    func logout(context: ServiceContext) async throws -> UUID?
}
