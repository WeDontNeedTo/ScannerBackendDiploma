import Vapor

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let dashboard = routes.grouped("dashboard")
        dashboard.get(use: index)
    }

    func index(req: Request) async throws -> DashboardResponse {
        do {
            let response = try await req.application.services.dashboardService.dashboard(
                context: ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
            )
            try await req.audit(action: "read", entity: "dashboard", message: "widgets")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }
}
