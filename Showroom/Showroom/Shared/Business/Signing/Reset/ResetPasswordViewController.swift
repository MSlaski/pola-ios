import UIKit
import RxSwift

class ResetPasswordViewController: UIViewController, ResetPasswordViewDelegate {
    private let disposeBag = DisposeBag()
    private let resolver: DiResolver
    private let toastManager: ToastManager
    private let model: ResetPasswordModel
    private var castView: ResetPasswordView { return view as! ResetPasswordView }
    
    init(resolver: DiResolver) {
        self.resolver = resolver
        self.toastManager = resolver.resolve(ToastManager.self)
        self.model = resolver.resolve(ResetPasswordModel.self)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = ResetPasswordView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        castView.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        logAnalyticsShowScreen(.ResetPassword)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        castView.registerOnKeyboardEvent()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        castView.unregisterOnKeyboardEvent()
    }
    
    // MARK: - ResetPasswordViewDelegate
    
    func resetPasswordViewDidReset() {
        guard let email = castView.email where castView.validate(showResult: true) else {
            return
        }
        
        castView.switcherState = .ModalLoading
        model.resetPassword(withEmail: email).subscribe { [weak self] (event: Event<Void>) in
            guard let `self` = self else { return }
            
            switch event {
            case .Next:
                self.castView.switcherState = .Empty //success
            case .Error(let error):
                logInfo("Error while reseting password \(error)")
                self.toastManager.showMessage(tr(.CommonError))
                self.castView.switcherState = .Success
            default: break
            }
        }.addDisposableTo(disposeBag)
    }
}