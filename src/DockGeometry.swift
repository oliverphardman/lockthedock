import CoreGraphics

public enum DockGeometry {
    public static func constrain(
        _ point: CGPoint,
        displays: [CGRect],
        allowed: Int,
        margin: CGFloat = 3,
        cornerSize: CGFloat = 5
    ) -> CGPoint {
        for (index, display) in displays.enumerated() where index != allowed {
            guard point.x >= display.minX, point.x < display.maxX,
                point.y > display.maxY - margin, point.y < display.maxY + 100
            else { continue }

            if point.x < display.minX + cornerSize || point.x >= display.maxX - cornerSize { continue }

            let below = CGPoint(x: point.x, y: display.maxY + 0.5)
            if displays.contains(where: { $0.contains(below) }) { continue }

            if displays.enumerated().contains(where: { $0.offset != index && $0.element.contains(point) }) {
                continue
            }

            return CGPoint(x: point.x, y: display.maxY - margin)
        }
        return point
    }
}
