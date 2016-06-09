import Foundation
import UIKit
import SnapKit
import RxSwift

protocol ProductDescriptionViewInterface: class {
    var headerHeight: CGFloat { get }
    var calculatedHeaderHeight: CGFloat { get }
}

protocol ProductPageViewDelegate: class {
    func pageView(pageView: ProductPageView, didChangePageViewState pageViewState: ProductPageViewState)
}

enum ProductPageViewState {
    case Default
    case ContentVisible
    case ImageGallery
}

class ProductPageView: UIView, UICollectionViewDelegateFlowLayout {
    private let defaultDescriptionTopMargin: CGFloat = 70
    private let descriptionDragVelocityThreshold: CGFloat = 200
    private let defaultContentAnimationDuration = 0.4
    
    private let imageCollectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: UICollectionViewFlowLayout())
    private let pageControl = VerticalPageControl()
    private let contentView: UIView
    private let buttonStackView = UIStackView()
    private let whishlistButton = UIButton()
    private let shareButton = UIButton()
    
    private let modelState: ProductPageModelState
    private let imageDataSource: ProductImageDataSource
    private let disposeBag = DisposeBag()
    
    private var contentTopConstraint: Constraint?
    private var viewState: ProductPageViewState = .Default {
        didSet {
            guard oldValue != viewState else { return }
            delegate?.pageView(self, didChangePageViewState: viewState)
            imageCollectionView.scrollEnabled = viewState != ProductPageViewState.ContentVisible
        }
    }
    private var viewsAlpha: CGFloat = 0 {
        didSet {
            contentView.alpha = viewsAlpha
            buttonStackView.alpha = viewsAlpha
            pageControl.alpha = viewsAlpha
        }
    }
    private weak var descriptionViewInterface: ProductDescriptionViewInterface?
    
    var currentImageIndex: Int {
        let pageHeight = imageCollectionView.frame.height
        return Int(imageCollectionView.contentOffset.y / pageHeight)
    }
    var contentInset: UIEdgeInsets?
    weak var delegate: ProductPageViewDelegate?
    
    init(contentView: UIView, descriptionViewInterface: ProductDescriptionViewInterface, modelState: ProductPageModelState) {
        self.contentView = contentView
        self.descriptionViewInterface = descriptionViewInterface
        self.modelState = modelState
        imageDataSource = ProductImageDataSource(collectionView: imageCollectionView)
        
        super.init(frame: CGRectZero)
        
        modelState.productDetailsObservable.subscribeNext(updateProductDetails).addDisposableTo(disposeBag)
        modelState.productObservable.subscribeNext(updateProduct).addDisposableTo(disposeBag)
        
        imageCollectionView.backgroundColor = UIColor.clearColor()
        imageCollectionView.dataSource = imageDataSource
        imageCollectionView.delegate = self
        imageCollectionView.pagingEnabled = true
        imageCollectionView.showsVerticalScrollIndicator = false
        imageCollectionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ProductPageView.didTapOnImageCollectionView)))
        let flowLayout = imageCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.scrollDirection = .Vertical
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        
        pageControl.alpha = viewsAlpha
        pageControl.currentPage = 0
        
        contentView.alpha = viewsAlpha
        contentView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(ProductPageView.didPanOnDescriptionView)))
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ProductPageView.didTapOnDescriptionView))
        tapGestureRecognizer.delegate = self
        contentView.addGestureRecognizer(tapGestureRecognizer)
        
        buttonStackView.alpha = viewsAlpha
        buttonStackView.axis = .Horizontal
        buttonStackView.spacing = 10
        
        whishlistButton.setImage(UIImage(asset: .Ic_do_ulubionych), forState: .Normal)
        whishlistButton.setImage(UIImage(asset: .Ic_w_ulubionych), forState: .Selected)
        whishlistButton.applyCircleStyle()
        
        shareButton.setImage(UIImage(asset: .Ic_share), forState: .Normal)
        shareButton.applyCircleStyle()
        
        buttonStackView.addArrangedSubview(whishlistButton)
        buttonStackView.addArrangedSubview(shareButton)
        
        addSubview(imageCollectionView)
        addSubview(pageControl)
        addSubview(contentView)
        addSubview(buttonStackView)
        
        configureCustomConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateProduct(product: Product?) {
        guard let p = product else { return }
        imageDataSource.imageUrls = [p.imageUrl]
    }
    
    private func updateProductDetails(productDetails: ProductDetails?) {
        guard let p = productDetails else { return }
        
        imageDataSource.imageUrls = p.images.map { $0.url }
        pageControl.numberOfPages = imageDataSource.imageUrls.count
        pageControl.invalidateIntrinsicContentSize()
        
        //todo it should not be here
        updateContentPosition(withAnimation: true)
    }
    
    private func updateContentPosition(withAnimation animation: Bool, animationDuration: Double = 0.3, completion: (() -> Void)? = nil) {
        //TODO add ImageGallery state handling
        let notVisibleOffset = (descriptionViewInterface?.calculatedHeaderHeight ?? 0) + (contentInset?.bottom ?? 0)
        let newDescriptionOffset = viewState == .ContentVisible ? defaultDescriptionTopMargin - bounds.height: -notVisibleOffset
        
        self.layoutIfNeeded()
        
        self.setNeedsLayout()
        UIView.animateWithDuration(animation ? animationDuration : 0) { [unowned self] in
            self.viewsAlpha = 1
            self.contentTopConstraint?.updateOffset(newDescriptionOffset)
            self.layoutIfNeeded()
        }
    }
    
    func changeViewState(viewState: ProductPageViewState, animated: Bool, completion: (() -> Void)? = nil) {
        self.viewState = viewState
        
        updateContentPosition(withAnimation: true, animationDuration: defaultContentAnimationDuration, completion: completion)
    }
    
    private func configureCustomConstraints() {
        imageCollectionView.snp_makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp_makeConstraints { make in
            contentTopConstraint = make.top.equalTo(contentView.superview!.snp_bottom).constraint
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalToSuperview().offset(-defaultDescriptionTopMargin)
        }
        
        pageControl.snp_makeConstraints { make in
            make.centerY.equalToSuperview().offset(-50)
            make.leading.equalTo(10)
        }
        
        buttonStackView.snp_makeConstraints { make in
            make.trailing.equalToSuperview().inset(Dimensions.defaultMargin)
            make.bottom.equalTo(contentView.snp_top).offset(-8)
        }
        
        shareButton.snp_makeConstraints { make in
            make.width.equalTo(Dimensions.circleButtonDiameter)
            make.height.equalTo(shareButton.snp_width)
        }
        
        whishlistButton.snp_makeConstraints { make in
            make.width.equalTo(Dimensions.circleButtonDiameter)
            make.height.equalTo(whishlistButton.snp_width)
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return self.bounds.size
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        pageControl.currentPage = currentImageIndex
    }
}

extension ProductPageView {
    func didPanOnDescriptionView(panGestureRecognizer: UIPanGestureRecognizer) {
        let bottomOffset = (descriptionViewInterface?.headerHeight ?? 0) + (contentInset?.bottom ?? 0)
        let movableY = bounds.height - defaultDescriptionTopMargin - bottomOffset
        var moveY = panGestureRecognizer.translationInView(contentView).y
        
        let contentVisible = viewState == .ContentVisible
        
        switch panGestureRecognizer.state {
        case .Changed:
            if contentVisible && moveY < 0 { moveY = 0 }
            else if contentVisible && moveY > movableY { moveY = movableY }
            else if !contentVisible && moveY > 0 { moveY = 0 }
            else if !contentVisible && moveY < -movableY { moveY = -movableY }
            
            let newOffset = contentVisible ? (defaultDescriptionTopMargin - bounds.height) + moveY: -bottomOffset + moveY
            self.contentTopConstraint?.updateOffset(newOffset)
        case .Ended:
            let movedMoreThanHalf = contentVisible && moveY > movableY * 0.5 || !contentVisible && moveY < -movableY * 0.5
            
            let yVelocity = panGestureRecognizer.velocityInView(contentView).y
            let movedFasterForward = contentVisible && yVelocity > descriptionDragVelocityThreshold || !contentVisible && yVelocity < -descriptionDragVelocityThreshold
            let movedFasterBackward = contentVisible && yVelocity < -descriptionDragVelocityThreshold || !contentVisible && yVelocity > descriptionDragVelocityThreshold
            
            if movedFasterForward || (movedMoreThanHalf && !movedFasterBackward) {
                viewState = contentVisible ? .Default : .ContentVisible
            }
            
            updateContentPosition(withAnimation: true, animationDuration: 0.2)
        default: break
        }
    }
    
    func didTapOnDescriptionView(tapGestureRecognizer: UITapGestureRecognizer) {
        let contentVisible = viewState == .ContentVisible
        viewState = contentVisible ? .Default : .ContentVisible
        updateContentPosition(withAnimation: true, animationDuration: defaultContentAnimationDuration)
    }
    
    func didTapOnImageCollectionView(tapGestureRecognizer: UITapGestureRecognizer) {
        switch viewState {
        case .Default: break //todo go to ImageGallery state
        case .ContentVisible:
            changeViewState(.Default, animated: true)
        case .ImageGallery: break // todo go back to Default state
        }
    }
}

extension ProductPageView: UIGestureRecognizerDelegate {
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if let touchHandlingDelegate = touch.view as? TouchHandlingDelegate {
            return !touchHandlingDelegate.shouldConsumeTouch(touch)
        }
        return true
    }
}