import Foundation

struct DashboardBalanceItemStats {
    let itemID: UUID
    let number: String
    let name: String
    let priceRub: Decimal
    let accumulatedPriceRub: Decimal
}

struct DashboardBalanceStats {
    let ownedItemsCount: Int
    let totalBalanceRub: Decimal
    let items: [DashboardBalanceItemStats]
}

struct DashboardBrokenItemStats {
    let brokenItemID: UUID
    let itemID: UUID
    let name: String
    let priceRub: Decimal?
    let reportedAt: Date
}
