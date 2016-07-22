import Foundation
import UIKit
import RxSwift

class SearchProductListViewController: UIViewController, ProductListViewControllerInterface, SearchProductListViewDelegate {
    typealias EntryData = EntrySearchInfo
    
    var disposeBag = DisposeBag()
    private let resolver: DiResolver
    let productListModel: ProductListModel
    private var model: SearchProductListModel { return productListModel as! SearchProductListModel }
    var productListView: ProductListViewInterface { return castView }
    private var castView: SearchProductListView { return view as! SearchProductListView }
    
    init(with resolver: DiResolver, entryData: EntrySearchInfo) {
        self.resolver = resolver
        productListModel = resolver.resolve(SearchProductListModel.self, argument: entryData)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = SearchProductListView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        castView.delegate = self
        castView.queryText = model.query
        
        automaticallyAdjustsScrollViewInsets = false
        navigationItem.titleView = castView.searchContainerView
        
        configureProductList()
        fetchFirstPage()
    }
    
    func updateData(with data: EntrySearchInfo) {
        disposeBag = DisposeBag()
        model.update(with: data)
        castView.queryText = model.query
        fetchFirstPage()
    }
    
    func createFilterButton() -> UIBarButtonItem? {
        return UIBarButtonItem(image: UIImage(asset: .Ic_filter), style: .Plain, target: self, action: #selector(didTapFilterButton))
    }
    
    func didTapFilterButton() {
        let viewController = resolver.resolve(ProductFilterNavigationController.self, argument: mockedFilter)
        viewController.filterDelegate = self
        presentViewController(viewController, animated: true, completion: nil)
    }
    
    func pageWasFetched(result productListResult: ProductListResult, page: Int) { }
    
    func filterButtonEnableStateChanged(toState enabled: Bool) {
        castView.searchEnabled = enabled
    }
    
    // MARK:- ProductListViewDelegate
    
    func viewSwitcherDidTapRetry(view: ViewSwitcher) {
        fetchFirstPage()
    }
    
    func searchProductList(view: SearchProductListView, didTapSearchWithQuery query: String) {
        model.query = query
        fetchFirstPage()
    }
    
    func searchProductListDidCancelEditing(view: SearchProductListView) {
        castView.queryText = model.query
    }
}

extension SearchProductListViewController: ProductFilterNavigationControllerDelegate { }