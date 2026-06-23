import Foundation

/// Describes a rectangular region within the output frame using normalized coordinates.
struct LayoutRegion: Codable, Equatable {
    var anchor: Anchor
    var normalizedRect: CGRect
    var padding: CGFloat
    var cornerRadius: CGFloat

    enum Anchor: String, Codable, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight, center, full
    }

    init(anchor: Anchor, normalizedRect: CGRect, padding: CGFloat, cornerRadius: CGFloat) {
        self.anchor = anchor
        self.normalizedRect = normalizedRect
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    /// Convert normalized region into pixel coordinates for a given container size.
    func rect(for containerSize: CGSize) -> CGRect {
        let x = normalizedRect.origin.x * containerSize.width
        let y = normalizedRect.origin.y * containerSize.height
        let width = normalizedRect.width * containerSize.width
        let height = normalizedRect.height * containerSize.height
        let base = CGRect(x: x, y: y, width: width, height: height)
        return base.insetBy(dx: padding, dy: padding)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case anchor, x, y, width, height, padding, cornerRadius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anchor = try container.decode(Anchor.self, forKey: .anchor)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        normalizedRect = CGRect(x: x, y: y, width: width, height: height)
        padding = try container.decode(CGFloat.self, forKey: .padding)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(normalizedRect.origin.x, forKey: .x)
        try container.encode(normalizedRect.origin.y, forKey: .y)
        try container.encode(normalizedRect.width, forKey: .width)
        try container.encode(normalizedRect.height, forKey: .height)
        try container.encode(padding, forKey: .padding)
        try container.encode(cornerRadius, forKey: .cornerRadius)
    }
}
