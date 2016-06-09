import Foundation
import Swinject

class ManagerAssembly: AssemblyType {
    func assemble(container: Container) {
        container.register(UserManager.self) { r in
            return UserManager(apiService: r.resolve(ApiService.self)!)
        }.inObjectScope(.Container)
        
        container.register(StorageManager.self) { r in
            return StorageManager()
        }.inObjectScope(.Container)
        
        container.register(BasketManager.self) { r in
            return BasketManager(storageManager: r.resolve(StorageManager.self)!)
        }.inObjectScope(.Container)
    }
}