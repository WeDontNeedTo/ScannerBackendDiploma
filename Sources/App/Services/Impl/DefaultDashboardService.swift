import Fluent
import Foundation

struct DefaultDashboardService: DashboardService {
    private let itemRepository: any ItemRepository
    private let userItemRepository: any UserItemRepository
    private let brokenItemRepository: any BrokenItemRepository

    init(repositories: RepositoryContainer) {
        self.itemRepository = repositories.itemRepository
        self.userItemRepository = repositories.userItemRepository
        self.brokenItemRepository = repositories.brokenItemRepository
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
            stats = DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero, items: [])
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
        let items =
            isAvailable
            ? stats.items.map { item in
                DashboardBalanceItemPayload(
                    itemID: item.itemID,
                    number: item.number,
                    name: item.name,
                    priceRub: item.priceRub,
                    accumulatedPriceRub: item.accumulatedPriceRub
                )
            }
            : []
        let widget = DashboardWidgetResponse(
            type: .balanceStatics,
            order: 1,
            isAvailable: isAvailable,
            payload: DashboardWidgetPayload(
                totalBalanceRub: totalBalance,
                currency: "RUB",
                items: items
            ),
            grabbedItemsPayload: nil,
            brokenItemsPayload: nil
        )

        let grabbed = try await userItemRepository.listApprovedForUser(
            userID: userID, on: context.db)
        let brokenItems = try await dashboardBrokenItems(
            for: user,
            userID: userID,
            grabbedUserItems: grabbed,
            db: context.db
        )
        print(brokenItems)
        let brokenItemIDs = Set(brokenItems.map(\.itemID))

        let grabbedItems = grabbed.compactMap { userItem -> DashboardGrabbedItemPayload? in
            guard let userItemID = userItem.id else {
                return nil
            }
            let item = userItem.item
            guard let itemID = item.id else {
                return nil
            }
            guard !brokenItemIDs.contains(itemID) else {
                return nil
            }
            return DashboardGrabbedItemPayload(
                userItemID: userItemID,
                itemID: itemID,
                number: item.number,
                name: item.name,
                description: item.description,
                priceRub: item.priceRub,
                grabbedAt: userItem.grabbedAt
            )
        }

        let grabbedWidget = DashboardWidgetResponse(
            type: .grabbedItems,
            order: 2,
            isAvailable: !grabbedItems.isEmpty,
            payload: DashboardWidgetPayload(
                totalBalanceRub: .zero,
                currency: "RUB",
                items: []
            ),
            grabbedItemsPayload: DashboardGrabbedItemsPayload(items: grabbedItems),
            brokenItemsPayload: nil
        )

        let brokenItemsWidget = DashboardWidgetResponse(
            type: .brokenItems,
            order: 3,
            isAvailable: !brokenItems.isEmpty,
            payload: DashboardWidgetPayload(
                totalBalanceRub: .zero,
                currency: "RUB",
                items: []
            ),
            grabbedItemsPayload: nil,
            brokenItemsPayload: DashboardBrokenItemsPayload(items: brokenItems)
        )

        return DashboardResponse(widgets: [widget, grabbedWidget, brokenItemsWidget])
    }
}

extension DefaultDashboardService {
    private func dashboardBrokenItems(
        for user: User,
        userID: UUID,
        grabbedUserItems: [UserItem],
        db: Database
    ) async throws -> [DashboardBrokenItemPayload] {
        let rows = try await brokenItemRepository.listWithItem(on: db)

        return rows.compactMap { broken in
            guard let brokenItemID = broken.id else {
                return nil
            }
            let itemID = broken.$item.id
            return DashboardBrokenItemPayload(
                brokenItemID: brokenItemID,
                itemID: itemID,
                name: broken.item.name,
                priceRub: broken.item.priceRub,
                reportedAt: broken.reportedAt
            )
        }
    }
}
