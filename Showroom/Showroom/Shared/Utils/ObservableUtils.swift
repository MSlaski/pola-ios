import Foundation
import RxSwift
import Decodable

extension Observable where Element: Decodable {
    static func retrieveFromCache(cacheId: String, storageManager: StorageManager) -> Observable<Element> {
        return Observable<Element>.create { observer in
            do {
                guard let cachedData: Element = try storageManager.loadFromCache(cacheId) else {
                    logInfo("No cache for cacheId: \(cacheId)")
                    observer.onCompleted()
                    return NopDisposable.instance
                }
                logInfo("Received cached for \(cacheId): \(cachedData)")
                observer.onNext(cachedData)
            } catch {
                observer.onError(error)
            }
            observer.onCompleted()
            return NopDisposable.instance
        }
    }
}

extension ObservableType where E: Encodable {
    func saveToCache(cacheId: String, storageManager: StorageManager) -> Observable<E> {
        return doOnNext { result in
            do {
                logInfo("Saving cache \(cacheId): \(result)")
                try storageManager.saveToCache(cacheId, object: result)
            } catch {
                logError("Error during caching \(cacheId): \(error)")
            }
        }
    }
}