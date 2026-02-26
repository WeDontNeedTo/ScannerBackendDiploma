import Vapor

struct RepositoryContainer {
    let itemRepository: any ItemRepository
    let userRepository: any UserRepository
    let userItemRepository: any UserItemRepository
    let itemLocationRepository: any ItemLocationRepository
    let itemLocationRequestRepository: any ItemLocationRequestRepository
    let inventoryRequestRepository: any InventoryRequestRepository
    let inventoryRequestItemRepository: any InventoryRequestItemRepository
    let itemJournalRepository: any ItemJournalRepository
    let brokenItemRepository: any BrokenItemRepository
    let itemCategoryRepository: any ItemCategoryRepository
    let locationRepository: any LocationRepository
    let itemParameterRepository: any ItemParameterRepository
    let userTokenRepository: any UserTokenRepository
}

struct ServiceContainer {
    let dashboardService: any DashboardService
    let itemService: any ItemService
    let itemLocationRequestService: any ItemLocationRequestService
    let inventoryRequestService: any InventoryRequestService
    let settingsUserService: any SettingsUserService
    let itemJournalService: any ItemJournalService
    let userItemService: any UserItemService
    let authService: any AuthService
    let userService: any UserService
    let locationService: any LocationService
    let itemCategoryService: any ItemCategoryService
    let itemParameterService: any ItemParameterService
}

extension Application {
    private struct RepositoryContainerKey: StorageKey {
        typealias Value = RepositoryContainer
    }

    private struct ServiceContainerKey: StorageKey {
        typealias Value = ServiceContainer
    }

    var repositories: RepositoryContainer {
        get {
            guard let value = storage[RepositoryContainerKey.self] else {
                fatalError("Repository container has not been configured.")
            }
            return value
        }
        set {
            storage[RepositoryContainerKey.self] = newValue
        }
    }

    var services: ServiceContainer {
        get {
            guard let value = storage[ServiceContainerKey.self] else {
                fatalError("Service container has not been configured.")
            }
            return value
        }
        set {
            storage[ServiceContainerKey.self] = newValue
        }
    }
}
