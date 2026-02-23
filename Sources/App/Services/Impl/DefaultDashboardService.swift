import Foundation

struct DefaultDashboardService: DashboardService {
    private let itemRepository: any ItemRepository

    init(repositories: RepositoryContainer) {
        self.itemRepository = repositories.itemRepository
    }

    func dashboard(context: ServiceContext) async throws -> DashboardResponse {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        guard let userID = user.id else {
            throw DomainError.unauthorized("Unauthorized")
        }

        let stats: DashboardBalanceStats
        if user.role == .employee {
            stats = DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero)
        } else {
            stats = try await itemRepository.dashboardBalanceStats(
                responsibleUserID: userID,
                on: context.db
            )
        }

        let isAvailable: Bool
        switch user.role {
        case .accountant, .admin:
            isAvailable = true
        case .materiallyResponsiblePerson:
            isAvailable = stats.ownedItemsCount > 0
        case .employee:
            isAvailable = false
        }

        let totalBalance = isAvailable ? stats.totalBalanceRub : Decimal.zero
        let widget = DashboardWidgetResponse(
            type: .balanceStatics,
            order: 1,
            isAvailable: isAvailable,
            payload: DashboardWidgetPayload(totalBalanceRub: totalBalance, currency: "RUB")
        )
        return DashboardResponse(widgets: [widget])
    }
}
