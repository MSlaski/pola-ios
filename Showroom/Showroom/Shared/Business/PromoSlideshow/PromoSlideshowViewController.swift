import Foundation
import UIKit
import RxSwift

final class PromoSlideshowViewController: UIViewController, PromoSlideshowViewDelegate, PromoPageDelegate {
    private let model: PromoSlideshowModel
    private var castView: PromoSlideshowView { return view as! PromoSlideshowView }
    private var indexedViewControllers: [Int: UIViewController] = [:]
    private var currentPage: PromoPageInterface? {
        guard let viewController = indexedViewControllers[castView.currentPageIndex], let promoPageInterface = viewController as? PromoPageInterface else {
            logError("View controller do not implement PromoPageInterface, for index \(castView.currentPageIndex), with viewcontroller: \(indexedViewControllers)")
            return nil
        }
        return promoPageInterface
    }
    private var lastAnalyticsSlideType: String?
    private var lastPageIndex = 0
    
    private let resolver: DiResolver
    private var disposeBag = DisposeBag()
    
    init(resolver: DiResolver, entry: PromoSlideshowEntry) {
        self.resolver = resolver
        self.model = resolver.resolve(PromoSlideshowModel.self, argument: entry)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = PromoSlideshowView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        castView.delegate = self
        castView.pageHandler = self
        
        fetchSlideshow()
        
        logAnalyticsEvent(AnalyticsEventId.VideoLaunch(model.entry.id))
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return castView.shouldProgressBeVisible
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        logAnalyticsShowScreen(AnalyticsScreenId.Video, refferenceUrl: model.entry.link)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PromoSlideshowViewController.onWillResignActive), name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PromoSlideshowViewController.onDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func updateData(with entry: PromoSlideshowEntry) {
        logAnalyticsShowScreen(AnalyticsScreenId.Video, refferenceUrl: entry.link)
        disposeBag = DisposeBag()
        lastPageIndex = 0
        castView.changeSwitcherState(.Loading)
        UIView.animateWithDuration(castView.viewSwitcherAnimationDuration) { [unowned self] in
            self.castView.progressEnded = false
            self.castView.viewState = .Playing
            self.setNeedsStatusBarAppearanceUpdate()
        }
        
        informCurrentChildViewController {
            $0.pageState = PromoPageState(focused: false, playing: false)
        }
        model.update(with: entry)
        logAnalyticsEvent(AnalyticsEventId.VideoLaunch(entry.id))
        fetchSlideshow()
    }
    
    private func fetchSlideshow() {
        logInfo("Fetching slideshow")
        model.fetchPromoSlideshow().subscribeNext { [weak self] fetchResult in
            guard let `self` = self else { return }
            
            switch fetchResult {
            case .Success(let result, _):
                logInfo("Fetched slideshow \(result)")
                self.castView.changeSwitcherState(.Success, animated: !self.castView.transitionViewVisible)
                if !self.castView.transitionAnimationInProgress {
                    self.castView.hideTransitionViewIfNeeded()
                }
                self.removeAllViewControllers()
                self.castView.update(with: result)
            case .CacheError(let error):
                logInfo("Cannot take cache for slideshow \(error)")
            case .NetworkError(let error):
                logInfo("Cannot fetch slideshow \(error)")
                if self.model.promoSlideshow == nil {
                    self.castView.changeSwitcherState(.Error, animated: !self.castView.transitionViewVisible)
                    if !self.castView.transitionAnimationInProgress {
                        self.castView.hideTransitionViewIfNeeded()
                    }
                }
            }
        }.addDisposableTo(disposeBag)
    }
    
    private func update(with viewState: PromoPageViewState, animationDuration: Double?, fromUserAction: Bool) {
        if fromUserAction {
            switch viewState {
            case .Paused where castView.viewState == .Playing:
                logAnalyticsEvent(AnalyticsEventId.VideoPause(model.entry.id))
            case .Playing:
                logAnalyticsEvent(AnalyticsEventId.VideoPlay(model.entry.id))
            default: break
            }
        }
        
        castView.update(with: viewState, animationDuration: animationDuration)
        UIView.animateWithDuration(animationDuration ?? 0) { [unowned self] in
            self.setNeedsStatusBarAppearanceUpdate()
        }
        
        if fromUserAction && viewState.isPausedState {
            if model.shouldShowPlayFeedback {
                castView.runPlayFeedback()
            }
            model.didShowPauseState()
        }
    }
    
    @objc private func onWillResignActive() {
        logInfo("will resign active")
        guard let currentPage = currentPage else {
            logError("There is not current child view controller for indexed: \(indexedViewControllers)")
            return
        }
        if castView.viewState.isPlayingState && !(currentPage is PromoSummaryViewController) {
            update(with: .Paused(currentPage.shouldShowProgressViewInPauseState), animationDuration: Constants.promoSlideshowStateChangedAnimationDuration, fromUserAction: false)
        }
        informCurrentChildViewController {
            $0.pageState = PromoPageState(focused: false, playing: false)
        }
    }
    
    @objc private func onDidBecomeActive() {
        logInfo("did become active")
        if currentPage is PromoSummaryViewController {
            informCurrentChildViewController {
                $0.pageState = PromoPageState(focused: true, playing: true)
            }
        }
    }
    
    private func informCurrentChildViewController(@noescape about block: PromoPageInterface -> Void) {
        let currentPageIndex = castView.currentPageIndex
        informChildViewControllers() {
            if $0 == currentPageIndex {
                block($1)
            }
        }
    }
    
    private func informChildViewControllers(@noescape about block: (Int, PromoPageInterface) -> Void) {
        for (index, viewController) in indexedViewControllers {
            if let promoPageInterface = viewController as? PromoPageInterface {
                block(index, promoPageInterface)
            } else {
                logError("View controller \(viewController) do not implement PromoPageInterface")
            }
        }
    }
    
    private func analyticsSlideTypeForCurrentChildViewController() -> String? {
        guard let currentPage = currentPage else {
            return nil
        }
        switch currentPage {
        case is VideoStepViewController:
            return "video"
        case is ImageStepViewController:
            return "image"
        case is ProductStepViewController:
            return "product"
        default: return nil
        }
    }
    
    private func sendCloseEvent() {
        logAnalyticsEvent(AnalyticsEventId.VideoClose(model.entry.id))
        sendNavigationEvent(SimpleNavigationEvent(type: .Close))
    }
    
    // MARK:- PromoSlideshowViewDelegate
    
    func promoSlideshowDidTapClose(promoSlideshow: PromoSlideshowView) {
        logInfo("Did tap close, state: \(castView.closeButtonState)")
        switch castView.closeButtonState {
        case .Close:
            sendCloseEvent()
        case .Dismiss:
            informCurrentChildViewController { $0.didTapDismiss() }
        case .Play:
            update(with: .Playing, animationDuration: Constants.promoSlideshowStateChangedAnimationDuration, fromUserAction: true)
        }
    }
    
    func promoSlideshowDidEndPageChanging(promoSlideshow: PromoSlideshowView, fromUserAction: Bool, afterLeftBounce: Bool) {
        logInfo("Did end page changing")
        guard let promo = model.promoSlideshow else {
            logError("No promo slideshow")
            return
        }
        
        let currentPageIndex = castView.currentPageIndex
        logInfo("current page index: \(currentPageIndex)")
        
        guard currentPageIndex != lastPageIndex else {
            informCurrentChildViewController {
                if afterLeftBounce {
                    $0.resetProgressState()
                    update(with: .Playing, animationDuration: Constants.promoSlideshowStateChangedAnimationDuration, fromUserAction: true)
                }
                $0.pageState = PromoPageState(focused: true, playing: castView.viewState.isPlayingState)
            }
            return
        }
        
        if currentPageIndex == promo.summaryPageIndex {
            UIView.animateWithDuration(Constants.promoSlideshowStateChangedAnimationDuration) { [unowned self] in
                self.castView.progressEnded = true
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
        
        if let lastAnalyticsSlideType = lastAnalyticsSlideType where fromUserAction {
            if currentPageIndex > lastPageIndex {
                logAnalyticsEvent(AnalyticsEventId.VideoSwipeRight(lastAnalyticsSlideType))
            } else if currentPageIndex < lastPageIndex {
                logAnalyticsEvent(AnalyticsEventId.VideoSwipeLeft(lastAnalyticsSlideType))
            }
        }
        
        informChildViewControllers() { (pageIndex, page) in
            if pageIndex == currentPageIndex {
                page.pageState = PromoPageState(focused: true, playing: true)
            } else {
                page.pageState = PromoPageState(focused: false, playing: true)
                page.resetProgressState()
            }
            
            logInfo("page index: \(pageIndex), set page state: \(page.pageState)")
        }
        
        update(with: .Playing, animationDuration: Constants.promoSlideshowStateChangedAnimationDuration, fromUserAction: true)
        
        lastPageIndex = currentPageIndex
    }
    
    func promoSlideshowWillBeginPageChanging(promoSlideshow: PromoSlideshowView) {
        logInfo("Will begin page changing, current page index: \(castView.currentPageIndex)")
        lastAnalyticsSlideType = analyticsSlideTypeForCurrentChildViewController()
        informCurrentChildViewController {
            $0.pageState = PromoPageState(focused: false, playing: castView.viewState.isPlayingState)
        }
    }
    
    func promoSlideshowView(promoSlideshow: PromoSlideshowView, didChangePlayingState playing: Bool) {
        informChildViewControllers() { (pageIndex, page) in
            let isCurrentPage = pageIndex == castView.currentPageIndex
            page.pageState = PromoPageState(focused: isCurrentPage, playing: playing)
        }
    }
    
    func promoSlideshowDidEndTransitionAnimation(promoSlideshow: PromoSlideshowView) {
        logInfo("Did end transition animation")
        if castView.viewSwitcherState == .Loading {
            castView.showTransitionLoader()
        } else {
            castView.hideTransitionViewIfNeeded()
        }
    }
    
    // MARK:- ViewSwitcherDelegate
    
    func viewSwitcherDidTapRetry(view: ViewSwitcher) {
        castView.changeSwitcherState(.Loading, animated: true)
        fetchSlideshow()
    }
    
    // MARK:- PromoStepDelegate
    
    func promoPageDidDownloadAllData(promoPage: PromoPageInterface) {
        logInfo("Did download all data for page \(promoPage)")
        guard let viewController = promoPage as? UIViewController else {
            logError("Promo page (\(promoPage))should be an UIViewController")
            return
        }
        guard let pageIndex = castView.pageIndex(forView: viewController.view) else {
            logError("Could not find page index for view controller \(viewController)")
            return
        }
        model.prefetchData(forPageAtIndex: pageIndex + 1)
    }
    
    func promoPage(promoPage: PromoPageInterface, didChangeCurrentProgress currentProgress: Double) {
        guard let currentPage = currentPage where currentPage.pageState.focused else {
            //take progress only from focused pages
            logInfo("Cannot update progress, page not focused, promoPage: \(promoPage)")
            return
        }
        let progressState = ProgressInfoState(currentStep: castView.currentPageIndex, currentStepProgress: currentProgress)
        castView.update(with: progressState)
    }
    
    func promoPage(promoPage: PromoPageInterface, willChangePromoPageViewState newViewState: PromoPageViewState, animationDuration: Double?) {
        logInfo("Will change promo page view state \(newViewState), aniamtionDuration \(animationDuration), for page \(promoPage)")
        update(with: newViewState, animationDuration: animationDuration, fromUserAction: true)
    }
    
    func promoPageDidFinished(promoStep: PromoPageInterface) {
        logInfo("Did finished \(promoStep)")
        if let promoSlideshow = model.promoSlideshow where promoStep is VideoStepViewController {
            logAnalyticsEvent(AnalyticsEventId.VideoSegmentWatched(promoSlideshow.id, promoSlideshow.video.steps[castView.currentPageIndex].duration))
        }
        if !castView.moveToNextPage() {
            sendCloseEvent()
        }
    }
}

extension PromoSlideshowViewController: TabBarStateDataSource {
    var prefersTabBarHidden: Bool {
        return true
    }
}

extension PromoSlideshowViewController: PromoSlideshowPageHandler {
    func page(forIndex index: Int, removePageIndex: Int?) -> UIView {
        logInfo("Creating page for index \(index), removePageIndex \(removePageIndex)")
        guard let data = model.data(forPageIndex: index) else {
            logInfo("Could not retrieve data")
            return UIView()
        }
        let currentViewController = removePageIndex == nil ? nil : indexedViewControllers[removePageIndex!]
        let newViewController = createViewController(from: data)
        
        guard let promoPageInterface = newViewController as? PromoPageInterface else {
            fatalError("View controller \(newViewController) must implement protocol PromoPageInterface")
        }
        promoPageInterface.pageDelegate = self
        
        currentViewController?.willMoveToParentViewController(nil)
        addChildViewController(newViewController)
        return newViewController.view
    }
    
    func pageAdded(forIndex index: Int, removePageIndex: Int?) {
        logInfo("Page added for index \(index), removePageIndex \(removePageIndex)")
        let currentViewController = removePageIndex == nil ? nil : indexedViewControllers[removePageIndex!]
        let newViewController = childViewControllers.last!
        
        currentViewController?.removeFromParentViewController()
        newViewController.didMoveToParentViewController(self)
        
        if indexedViewControllers.isEmpty {
            (newViewController as? PromoPageInterface)?.pageState = PromoPageState(focused: true, playing: castView.viewState.isPlayingState)
        }
        
        if removePageIndex != nil {
            indexedViewControllers[removePageIndex!] = nil
        }
        indexedViewControllers[index] = newViewController
        logInfo("Indexed view controllers \(indexedViewControllers)")
    }
    
    private func removeAllViewControllers() {
        logInfo("Remove all view controllers \(indexedViewControllers)")
        indexedViewControllers.forEach { (index, viewController) in
            viewController.forceCloseModal()
            viewController.willMoveToParentViewController(nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParentViewController()
        }
        indexedViewControllers.removeAll()
    }
    
    private func createViewController(from dataContainer: PromoSlideshowPageDataContainer) -> UIViewController {
        logInfo("Creating view controller with dataContainer: \(dataContainer)")
        
        let newPageState = PromoPageState(focused: false, playing: true)
        
        switch dataContainer.pageData {
        case .Image(let link, let duration):
            return resolver.resolve(ImageStepViewController.self, arguments: (link, duration, newPageState))
        case .Video(let link, let annotations):
            return resolver.resolve(VideoStepViewController.self, arguments: (link, annotations, dataContainer.additionalData, newPageState))
        case .Product(let dataEntry):
            return resolver.resolve(ProductStepViewController.self, arguments: (dataEntry, newPageState))
        case .Summary(let promoSlideshow):
            return resolver.resolve(PromoSummaryViewController.self, arguments: (promoSlideshow, newPageState))
        }
    }
}

extension PromoSlideshowViewController: NavigationHandler {
    func handleNavigationEvent(event: NavigationEvent) -> EventHandled {
        if let videoEvent = event as? ShowPromoSlideshowEvent {
            updateData(with: videoEvent.entry)
            return true
        }
        return false
    }
}

extension PromoSlideshowViewController: StatusBarAppearanceHandling {
    var wantsHandleStatusBarAppearance: Bool {
        return true
    }
}

extension PromoSlideshowViewController: PresenterModalProtocol {
    func presenterWillCloseModalWithPan() {
        logAnalyticsEvent(AnalyticsEventId.VideoClose(model.entry.id))
    }
}
