import Foundation
import Decodable

//taken from https://medium.com/swift-programming/creating-a-money-type-in-swift-3b060fb762ed#.3e666p8j5

enum Currency {
    case Zl
    
    var stringValue: String {
        get {
            switch self {
            case Zl:
                return tr(.MoneyZl)
            }
        }
    }
}

struct Money: Comparable {
    let money: (NSDecimalNumber, Currency)
    
    static let decimalHandler = NSDecimalNumberHandler(roundingMode: .RoundDown, scale: 2, raiseOnExactness: true, raiseOnOverflow: true, raiseOnUnderflow: true, raiseOnDivideByZero: true)
    
    init(amt: Float, currency: Currency = .Zl) {
        money = (NSDecimalNumber(float: amt), currency)
    }
    
    init(amt: NSDecimal, currency: Currency = .Zl) {
        money = (NSDecimalNumber(decimal: amt), currency)
    }
    
    init(amt: Double, currency: Currency = .Zl) {
        money = (NSDecimalNumber(double: amt), currency)
    }
    
    var amount: Float {
        get {
            return money.0.decimalNumberByRoundingAccordingToBehavior(Money.decimalHandler).floatValue
        }
    }
    
    var currency: Currency {
        get {
            return money.1
        }
    }
    
    var stringValue: String {
        get {
            return String(format: "%.2f \(currency.stringValue)", amount)
        }
    }
}

enum MoneyDecodeError: ErrorType {
    case CannotDecodeType(String)
}

extension Money: Decodable {
    static func decode(j: AnyObject) throws -> Money {
        if let amt = j as? Double {
            return Money(amt: amt)
        } else if let amt = j as? Float {
            return Money(amt: amt)
        }
        throw MoneyDecodeError.CannotDecodeType(String(j))
    }
}

func +(lhs: Money, rhs: Money) -> Money {
    if lhs.currency == rhs.currency {
        let money = lhs.money.0.decimalNumberByAdding(rhs.money.0)
        return Money(amt: money.floatValue, currency: lhs.currency)
    }
    
    return Money(amt: 0.0, currency: lhs.currency)
}

func +(lhs:Money, rhs: Float) -> Money {
    let amount = lhs.amount + rhs
    return Money(amt: amount, currency: lhs.currency)
}

func +(lhs:Float, rhs: Money) -> Money {
    let amount = lhs + rhs.amount
    return Money(amt: amount, currency: rhs.currency)
}

func ==(lhs: Money, rhs: Money) -> Bool {
    return lhs.money.0.compare(rhs.money.0) == .OrderedSame && lhs.currency == rhs.currency
}

func <(lhs: Money, rhs: Money) -> Bool {
    return lhs.currency == rhs.currency && lhs.amount < rhs.amount
}