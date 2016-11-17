import Foundation
import UIKit
import RxSwift

final class SearchViewController: UIViewController, SearchViewDelegate {
    private let disposeBag = DisposeBag()
    private let resolver: DiResolver
    private var castView: SearchView { return view as! SearchView }
    private let model: SearchModel
    private var indexedViewControllers: [Int: UIViewController] = [:]
    
    init(with resolver: DiResolver) {
        self.resolver = resolver
        self.model = resolver.resolve(SearchModel.self)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = SearchView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = false
        
        castView.pageHandler = self
        castView.delegate = self
        
        model.genderObservable.subscribeNext { [weak self] gender in
            self?.updateSelectedTab()
        }.addDisposableTo(disposeBag)
        fetchSearchItems()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        logAnalyticsShowScreen(.Search)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        markHandoffUrlActivity(withType: .Home, resolver: resolver)
        // We need to update content inset on didAppear in case when app starts with video deep link, that hides status bar.
        // Than when returning back we don't get viewDidLayoutSubviews when status bar is again shown.
        updateContentInset()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentInset()
    }
    
    private func fetchSearchItems() {
        model.fetchSearchItems().subscribeNext { [weak self] (cacheResult: FetchCacheResult<SearchResult>) in
            guard let `self` = self else { return }
            switch cacheResult {
            case .Success(let result):
                self.removeAllViewControllers()
                self.castView.changeSwitcherState(.Success)
                self.castView.updateData(with: result.rootItems)
                self.updateSelectedTab()
            case .CacheError(let error):
                logError("Error while fetching cached search result \(error)")
                break
            case .NetworkError(let error):
                logInfo("Couldn't download search result \(error)")
                if self.model.searchResult == nil {
                    self.castView.changeSwitcherState(.Error)
                }
                break
            }
        }.addDisposableTo(disposeBag)
    }
    
    private func updateSelectedTab() {
        guard let rootItems = model.searchResult?.rootItems else { return }
        let gender = model.userGender
        guard let selectedIndex = rootItems.indexOf({ $0.gender == gender }) else { return }
        castView.selectedTab = selectedIndex
    }
    
    private func updateContentInset() {
        castView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: bottomLayoutGuide.length, right: 0)
    }
    
    //MARK:- SearchViewDelegate
    
    func search(view: SearchView, didTapSearchWithQuery query: String) {
        logAnalyticsEvent(AnalyticsEventId.Search(query))
        sendNavigationEvent(ShowProductSearchEvent(query: query))
    }
    
    func search(view: SearchView, didChangeMainMenuToIndex index: Int) {
        logAnalyticsEvent(AnalyticsEventId.SearchMainMenuClick(model.searchResult?.rootItems[index].name ?? ""))
    }
    
    func viewSwitcherDidTapRetry(view: ViewSwitcher) {
        castView.changeSwitcherState(.Loading)
        fetchSearchItems()
    }
}

extension SearchViewController: SearchPageHandler {
    func page(forIndex index: Int) -> UIView {
        let indexedViewController = indexedViewControllers[index]
        let viewController = indexedViewController ?? createViewController(forIndex: index)
        if indexedViewController == nil {
            addChildViewController(viewController)
            indexedViewControllers[index] = viewController
        }
        return viewController.view
    }
    
    func pageAdded(forIndex index: Int) {
        let newViewController = indexedViewControllers[index]!
        newViewController.didMoveToParentViewController(self)
    }
    
    private func createViewController(forIndex index: Int) -> UIViewController {
        guard let searchResult = model.searchResult else { fatalError("Cannot create viewcontroller when searchResult is nil") }
        return resolver.resolve(SearchContentNavigationController.self, argument: searchResult.rootItems[index])
    }
    
    private func removeAllViewControllers() {
        indexedViewControllers.forEach { (index, viewController) in
            viewController.willMoveToParentViewController(nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParentViewController()
        }
        indexedViewControllers.removeAll()
    }
}
