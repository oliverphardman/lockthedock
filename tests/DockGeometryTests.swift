import CoreGraphics
import Testing

struct DockGeometryTests {
    private let sideBySide = [
        CGRect(x: 0, y: 0, width: 1000, height: 800),
        CGRect(x: 1000, y: 0, width: 1000, height: 800),
    ]

    private let stacked = [
        CGRect(x: 0, y: 800, width: 1000, height: 800),
        CGRect(x: 200, y: 0, width: 1000, height: 800),
    ]

    private func constrain(_ x: CGFloat, _ y: CGFloat, _ displays: [CGRect], allowed: Int = 0) -> CGPoint {
        DockGeometry.constrain(CGPoint(x: x, y: y), displays: displays, allowed: allowed)
    }

    @Test func allowedDisplayIsUntouched() {
        #expect(constrain(500, 799, sideBySide) == CGPoint(x: 500, y: 799))
    }

    @Test func otherDisplayIsHeldBack() {
        #expect(constrain(1500, 799, sideBySide) == CGPoint(x: 1500, y: 797))
    }

    @Test func overshootIsHeldBack() {
        #expect(constrain(1500, 830, sideBySide) == CGPoint(x: 1500, y: 797))
    }

    @Test func middleOfScreenIsUntouched() {
        #expect(constrain(1500, 400, sideBySide) == CGPoint(x: 1500, y: 400))
    }

    @Test func choiceOfDisplayIsRespected() {
        #expect(constrain(500, 799, sideBySide, allowed: 1) == CGPoint(x: 500, y: 797))
    }

    @Test func canCrossDownwards() {
        #expect(constrain(500, 799, stacked) == CGPoint(x: 500, y: 799))
    }

    @Test func hasArrivedBelow() {
        #expect(constrain(500, 801, stacked) == CGPoint(x: 500, y: 801))
    }

    @Test func overhangIsHeldBack() {
        #expect(constrain(1100, 799, stacked) == CGPoint(x: 1100, y: 797))
    }

    @Test(arguments: [1000, 1004.9, 1995, 1999])
    func bottomCornersStayReachable(x: Double) {
        #expect(constrain(x, 799, sideBySide) == CGPoint(x: x, y: 799))
    }

    @Test(arguments: [1005, 1994.9])
    func edgeBesideCornerIsHeldBack(x: Double) {
        #expect(constrain(x, 799, sideBySide) == CGPoint(x: x, y: 797))
    }
}
