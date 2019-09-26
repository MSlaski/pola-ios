import UIKit

class ResultContentViewControllerFactory {
    
    static func create(scanResult: BPScanResult) -> UIViewController {
        if let altText = scanResult.altText,
            !altText.isEmpty {
            return AltResultContentViewController(result: scanResult)
        }
        return CompanyContentViewController(result: scanResult)
    }
}
