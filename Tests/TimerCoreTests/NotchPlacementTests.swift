import Foundation
import CoreGraphics
import Testing
@testable import TimerCore

@Test func expansionPreservesTopCenterAwayFromEdges() {
    let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let anchor = CGPoint(x: 600, y: 500)
    for size in [CGSize(width: 100, height: 22), CGSize(width: 360, height: 44)] {
        let frame = NotchPlacement.frame(size: size, anchor: anchor, bounds: bounds)
        #expect(frame.midX == anchor.x)
        #expect(frame.maxY == anchor.y)
    }
}

@Test func expandedNotchStaysVisibleAtEveryScreenEdge() {
    let bounds = CGRect(x: 4, y: 4, width: 1432, height: 860)
    for anchor in [CGPoint(x: -200, y: 1100), CGPoint(x: 1700, y: 1100),
                   CGPoint(x: -200, y: -200), CGPoint(x: 1700, y: -200)] {
        let frame = NotchPlacement.frame(size: CGSize(width: 360, height: 44), anchor: anchor, bounds: bounds)
        #expect(bounds.contains(frame))
    }
}

@Test func placementSupportsDisplaysWithNegativeCoordinates() {
    let bounds = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
    let frame = NotchPlacement.frame(size: CGSize(width: 360, height: 44),
                                     anchor: CGPoint(x: -1900, y: -1060), bounds: bounds)
    #expect(bounds.contains(frame))
    #expect(frame.minX == -1920)
    #expect(frame.minY == -1080)
}

@Test func edgeExpansionDoesNotChangeTheCompactAnchor() {
    let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let anchor = CGPoint(x: 50, y: 880)
    let expanded = NotchPlacement.frame(size: CGSize(width: 360, height: 44), anchor: anchor, bounds: bounds)
    let compact = NotchPlacement.frame(size: CGSize(width: 100, height: 22), anchor: anchor, bounds: bounds)
    #expect(expanded.minX == 0)
    #expect(compact.midX == anchor.x)
    #expect(compact.maxY == anchor.y)
}
