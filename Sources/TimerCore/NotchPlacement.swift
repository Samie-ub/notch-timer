import Foundation
import CoreGraphics

/// Positions either notch size around the same top-center anchor, keeping it visible.
public enum NotchPlacement {
    public static func frame(size: CGSize, anchor: CGPoint, bounds: CGRect) -> CGRect {
        let x = min(max(anchor.x - size.width / 2, bounds.minX), max(bounds.minX, bounds.maxX - size.width))
        let y = min(max(anchor.y - size.height, bounds.minY), max(bounds.minY, bounds.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
