import Foundation
import RxSwift

final class GratisOptionHandler: PaymentOptionHandler {
    let paymentTypes = [PaymentType.Gratis, PaymentType.GratisDe]
    weak var delegate: PaymentHandlerDelegate?
    var isPayMethodSelected: Bool { return true }
    
    func makePayment(with info: PaymentInfo, createPaymentRequest: Nonce? -> Observable<PaymentResult>) -> Observable<PaymentResult> {
        return createPaymentRequest(nil)
    }
    
    func createPayMethodView(frame: CGRect) -> UIView? {
        return nil
    }
    
    func handleOpenURL(url: NSURL, sourceApplication: String?) -> Bool {
        return false
    }
}
