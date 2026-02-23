import Foundation
import Vapor

struct DashboardResponse: Content {
    let widgets: [DashboardWidgetResponse]
}

enum DashboardWidgetType: String, Content {
    case balanceStatics = "balance_statics"
}

struct DashboardWidgetResponse: Content {
    let type: DashboardWidgetType
    let order: Int
    let isAvailable: Bool
    let payload: DashboardWidgetPayload
}

struct DashboardWidgetPayload: Content {
    let totalBalanceRub: Decimal
    let currency: String
}
