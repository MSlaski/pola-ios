import UIKit

@objc(BPCheckRow)
class CheckRow: UIView {
    private let checkImageView = UIImageView()
    private let textLabel = UILabel()
    private let horizontalMargin = CGFloat(7)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        checkImageView.tintColor = BPTheme.defaultTextColor()
        addSubview(checkImageView)
        
        textLabel.font = BPTheme.normalFont()
        textLabel.textColor = BPTheme.defaultTextColor()
        addSubview(textLabel)
        
        accessibilityTraits = .staticText
        isAccessibilityElement = true
        
        checked = nil
        updateCheckedUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    var text: String? {
        didSet {
            textLabel.text = text
            accessibilityLabel = text
            textLabel.sizeToFit()
            setNeedsLayout()
        }
    }
    
    @nonobjc
    var checked: Bool? {
        didSet {
            updateCheckedUI()
        }
    }
    
    private func updateCheckedUI() {
        let image: UIImage?
        switch checked {
        case true:
            image = R.image.trueIcon()
            accessibilityValue = R.string.localizable.accessibilityCheckRowSelected()
            
        case false:
            image = R.image.falseIcon()
            accessibilityValue = R.string.localizable.accessibilityCheckRowNotSelected()
            
        default:
            image = R.image.noneIcon()
            accessibilityValue = R.string.localizable.accessibilityCheckRowUnknown()
        }
        
        checkImageView.image = image?.withRenderingMode(.alwaysTemplate)
        checkImageView.sizeToFit()
        setNeedsLayout()
    }
    
    @objc(checked)
    var _checked: NSNumber? {
        get {
            guard let checked = checked else {
                return nil
            }
            return NSNumber(booleanLiteral: checked)
        }
        set {
            checked = newValue?.boolValue
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var rect = checkImageView.frame
        rect.origin.x = 0
        rect.origin.y = bounds.height / 2 - rect.height / 2
        checkImageView.frame = rect
        
        rect = textLabel.frame
        rect.origin.x = checkImageView.frame.maxX + horizontalMargin;
        rect.origin.y = bounds.height / 2 - rect.height / 2;
        self.textLabel.frame = rect;
    }
    
    override func sizeThatFits(_ : CGSize) -> CGSize {
        let width = checkImageView.bounds.width + horizontalMargin + textLabel.bounds.width
        let height = max(checkImageView.bounds.height, textLabel.bounds.height)
        return CGSize(width: width, height: height)
    }
    
}
