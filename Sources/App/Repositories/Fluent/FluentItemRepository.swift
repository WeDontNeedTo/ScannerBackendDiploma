import Fluent
import Foundation

struct FluentItemRepository: ItemRepository {
    func listWithRelations(on db: Database) async throws -> [Item] {
        try await Item.query(on: db)
            .with(\.$parameters)
            .with(\.$category)
            .all()
    }

    func findWithRelations(id: UUID, on db: Database) async throws -> Item? {
        try await Item.query(on: db)
            .filter(\.$id == id)
            .with(\.$parameters)
            .with(\.$category)
            .first()
    }

    func findWithRelations(number: String, on db: Database) async throws -> Item? {
        try await Item.query(on: db)
            .filter(\.$number == number)
            .with(\.$parameters)
            .with(\.$category)
            .first()
    }

    func search(with data: ItemSearchData, on db: Database) async throws -> [Item] {
        let term = data.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = data.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = data.number?.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsibleUserID = data.responsibleUserID
        let per = data.per ?? 50

        let hasSearchCriteria =
            (term?.isEmpty == false) || (name?.isEmpty == false) || (number?.isEmpty == false)
            || responsibleUserID != nil

        var itemsQuery = Item.query(on: db)
            .with(\.$parameters)
            .with(\.$category)

        if hasSearchCriteria {
            let page = data.page ?? 1
            if let term, !term.isEmpty {
                itemsQuery = itemsQuery.group(.or) { group in
                    group.filter(\.$name, .custom("ILIKE"), "%\(term)%")
                    group.filter(\.$number, .custom("ILIKE"), "%\(term)%")
                }
            } else {
                if let name, !name.isEmpty {
                    itemsQuery = itemsQuery.filter(\.$name, .custom("ILIKE"), "%\(name)%")
                }
                if let number, !number.isEmpty {
                    itemsQuery = itemsQuery.filter(\.$number, .custom("ILIKE"), "%\(number)%")
                }
            }
            if let responsibleUserID {
                itemsQuery = itemsQuery.filter(\.$responsibleUser.$id == responsibleUserID)
            }
            if data.page != nil || data.per != nil {
                let offset = (page - 1) * per
                itemsQuery = itemsQuery.range(offset..<(offset + per))
            }
        } else {
            itemsQuery = itemsQuery.range(0..<per)
        }

        return try await itemsQuery.all()
    }

    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats {
        let items = try await Item.query(on: db)
            .filter(\.$responsibleUser.$id == responsibleUserID)
            .all()

        let pricedItems = items.compactMap { item -> DashboardBalanceItemStats? in
            guard let itemID = item.id, let priceRub = item.priceRub else {
                return nil
            }
            return DashboardBalanceItemStats(
                itemID: itemID,
                number: item.number,
                name: item.name,
                priceRub: priceRub,
                accumulatedPriceRub: priceRub
            )
        }

        let totalBalanceRub = pricedItems.reduce(Decimal.zero) { partial, item in
            partial + item.accumulatedPriceRub
        }

        return DashboardBalanceStats(
            ownedItemsCount: items.count,
            totalBalanceRub: totalBalanceRub,
            items: pricedItems
        )
    }

    func countByResponsibleUser(responsibleUserID: UUID, on db: Database) async throws -> Int {
        try await Item.query(on: db)
            .filter(\.$responsibleUser.$id == responsibleUserID)
            .count()
    }

    func listByResponsibleUserWithRelations(responsibleUserID: UUID, on db: Database) async throws -> [Item] {
        try await Item.query(on: db)
            .filter(\.$responsibleUser.$id == responsibleUserID)
            .with(\.$parameters)
            .with(\.$category)
            .with(\.$responsibleUser)
            .all()
    }

    func findAllByIDs(_ ids: [UUID], on db: Database) async throws -> [Item] {
        guard !ids.isEmpty else { return [] }
        return try await Item.query(on: db)
            .filter(\.$id ~~ ids)
            .all()
    }

    func findAllByIDsWithRelations(_ ids: [UUID], on db: Database) async throws -> [Item] {
        guard !ids.isEmpty else { return [] }
        return try await Item.query(on: db)
            .filter(\.$id ~~ ids)
            .with(\.$parameters)
            .with(\.$category)
            .with(\.$responsibleUser)
            .all()
    }

    func saveAll(_ items: [Item], on db: Database) async throws {
        for item in items {
            try await item.save(on: db)
        }
    }

    func find(id: UUID, on db: Database) async throws -> Item? {
        try await Item.find(id, on: db)
    }

    func save(_ item: Item, on db: Database) async throws {
        try await item.save(on: db)
    }

    func delete(_ item: Item, on db: Database) async throws {
        try await item.delete(on: db)
    }
}
