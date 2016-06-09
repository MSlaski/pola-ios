import Quick
import Nimble
@testable import SHOWROOM

class MoneyTests: QuickSpec {
    override func spec() {
        describe("converting to string") {
            it("for different values") {
                expect(Money(amt: 0.0).stringValue) == "0.00 zł"
                expect(Money(amt: 10.53).stringValue) == "10.53 zł"
                expect(Money(amt: 10.53912302193123).stringValue) == "10.53 zł"
                expect(Money(amt: 10.53212302193123).stringValue) == "10.53 zł"
            }
        }
        describe("calculating discount price") {
            context("without decimal points") {
                let original = Money(amt: 100.0)
                let discounted = Money(amt: 50.0)
                let original1 = Money(amt: 100.0)
                let discounted1 = Money(amt: 55.0)
                
                it("should return correct value") {
                    expect(discounted.calculateDiscountPercent(fromMoney: original)) == 50
                    expect(discounted1.calculateDiscountPercent(fromMoney: original1)) == 45
                }
            }
            
            context("with decimal points") {
                let original = Money(amt: 101.0)
                let discounted = Money(amt: 55.0)
                let discounted1 = Money(amt: 55.2)
                
                it("should return correct value") {
                    //result is 45,54
                    expect(discounted.calculateDiscountPercent(fromMoney: original)) == 46
                    //result is 45,34
                    expect(discounted1.calculateDiscountPercent(fromMoney: original)) == 45
                }
            }
        }
    }
}