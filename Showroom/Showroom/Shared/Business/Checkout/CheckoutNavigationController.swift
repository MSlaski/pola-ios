import UIKit

class CheckoutNavigationController: UINavigationController, NavigationHandler {
    private let resolver: DiResolver
    private let model: CheckoutModel
    
    init(with resolver: DiResolver, and checkout: Checkout) {
        self.resolver = resolver
        self.model = resolver.resolve(CheckoutModel.self, argument: checkout)
        super.init(nibName: nil, bundle: nil)
        
        navigationBar.applyWhiteStyle()
        
        let checkoutDeliveryViewController = resolver.resolve(CheckoutDeliveryViewController.self, argument: model)
        checkoutDeliveryViewController.navigationItem.title = tr(.CheckoutDeliveryNavigationHeader)
        
        checkoutDeliveryViewController.applyBlackCloseButton(target: self, action: #selector(CheckoutNavigationController.didTapCloseButton))
        
        viewControllers = [checkoutDeliveryViewController]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showSummaryView() {
        let summaryViewController = resolver.resolve(CheckoutSummaryViewController.self, argument: model)
        summaryViewController.navigationItem.title = tr(.CheckoutSummaryNavigationHeader)
        summaryViewController.applyBlackBackButton(target: self, action: #selector(CheckoutNavigationController.didTapBackButton))
        pushViewController(summaryViewController, animated: true)
    }
    
    func showEditAddressView(userAddress userAddress: UserAddress?) {
        let editAddressViewController = resolver.resolve(EditAddressViewController.self, arguments: (userAddress, model.state.checkout.deliveryCountry.name))
        editAddressViewController.delegate = self
        editAddressViewController.navigationItem.title = tr(.CheckoutDeliveryEditAddressNavigationHeader)
        editAddressViewController.applyBlackBackButton(target: self, action: #selector(CheckoutNavigationController.didTapBackButton))
        pushViewController(editAddressViewController, animated: true)
    }
    
    func showEditKioskView() {
        let editKioskViewController = resolver.resolve(EditKioskViewController.self, argument: model)
        editKioskViewController.delegate = self
        editKioskViewController.navigationItem.title = tr(.CheckoutDeliveryNavigationHeader)
        editKioskViewController.applyBlackBackButton(target: self, action: #selector(CheckoutNavigationController.didTapBackButton))
        pushViewController(editKioskViewController, animated: true)
    }
    
    func didTapCloseButton(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func didTapBackButton(sender: UIBarButtonItem) {
        popViewControllerAnimated(true)
    }
    
    func handleNavigationEvent(event: NavigationEvent) -> EventHandled {
        switch event {
        case let simpleEvent as SimpleNavigationEvent:
            switch simpleEvent.type {
            case .ShowCheckoutSummary:
                showSummaryView()
                return true
            case .ShowEditKiosk:
                showEditKioskView()
                return true
            default:
                return false
            }
            
        case let editAddressEvent as ShowEditAddressEvent:
            showEditAddressView(userAddress: editAddressEvent.userAddress)
            return true
            
        default:
            return false
        }
    }
}

extension CheckoutNavigationController: EditKioskViewControllerDelegate {
    func editKioskViewControllerDidChooseKiosk(viewController: EditKioskViewController, kiosk: Kiosk) {
        model.state.selectedKiosk = kiosk
        popViewControllerAnimated(true)
    }
}

// MARK: - EditAddressViewControllerDelegate

extension CheckoutNavigationController: EditAddressViewControllerDelegate {
    func editAddressViewController(viewController: EditAddressViewController, didAddNewUserAddress userAddress: UserAddress) {
        model.state.addressAdded = true
        model.state.userAddresses.append(userAddress)
        popViewControllerAnimated(true)
    }
    
    func editAddressViewController(viewController: EditAddressViewController, didEditUserAddress userAddress: UserAddress) {
        model.state.userAddresses[model.state.userAddresses.count - 1] = userAddress
        popViewControllerAnimated(true)
    }

}