import Foundation
import UIKit

struct DimTransitionAnimation: TransitionAnimation {
    let animationDuration: NSTimeInterval
    
    func show(containerView: ContainerView, presentedView: PresentedView, presentationView: PresentationView?, completion: ((Bool) -> ())?) {
        logInfo("Showing with dim animation")
        if let presentationView = presentationView {
            presentationView.alpha = 1.0
            UIView.animateWithDuration(animationDuration, animations: {
                presentationView.alpha = 0.0
                }, completion: completion)
        } else {
            presentedView.alpha = 0.0
            UIView.animateWithDuration(animationDuration, animations: {
                presentedView.alpha = 1.0
                }, completion: completion)
        }
    }
    
    func hide(containerView: ContainerView, presentedView: PresentedView, presentationView: PresentationView?, completion: ((Bool) -> ())?) {
        logInfo("Hiding with dim animation")
        presentedView.alpha = 1.0
        UIView.animateWithDuration(animationDuration, animations: {
            presentedView.alpha = 0.0
            }, completion: completion)
    }
}

