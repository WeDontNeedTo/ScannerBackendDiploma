import Foundation
import Vapor

struct DashboardResponse: Content {
    let widgets: [DashboardWidgetResponse]
}

enum DashboardWidgetType: String, Content {
    case balanceStatics = "balance_statics"
    case grabbedItems = "grabbed_items"
    case brokenItems = "broken_items"
}

struct DashboardWidgetResponse: Content {
    let type: DashboardWidgetType
    let order: Int
    let isAvailable: Bool
    let payload: DashboardWidgetPayload
    let grabbedItemsPayload: DashboardGrabbedItemsPayload?
    let brokenItemsPayload: DashboardBrokenItemsPayload?
}

struct DashboardBalanceItemPayload: Content {
    let itemID: UUID
    let number: String
    let name: String
    let priceRub: Decimal
    let accumulatedPriceRub: Decimal
}

struct DashboardWidgetPayload: Content {
    let totalBalanceRub: Decimal
    let currency: String
    let items: [DashboardBalanceItemPayload]
}

struct DashboardGrabbedItemPayload: Content {
    let userItemID: UUID
    let itemID: UUID
    let number: String
    let name: String
    let description: String?
    let priceRub: Decimal?
    let grabbedAt: Date?
}

struct DashboardGrabbedItemsPayload: Content {
    let items: [DashboardGrabbedItemPayload]
}

struct DashboardBrokenItemPayload: Content {
    let brokenItemID: UUID
    let itemID: UUID
    let name: String
    let priceRub: Decimal?
    let reportedAt: Date
}

struct DashboardBrokenItemsPayload: Content {
    let items: [DashboardBrokenItemPayload]
}
