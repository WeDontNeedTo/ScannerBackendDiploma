import Vapor

protocol DashboardService {
    func dashboard(context: ServiceContext) async throws -> DashboardResponse
}
