import CoreGraphics

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let chip: CGFloat = 6
    static let button: CGFloat = 8
    static let card: CGFloat = 12
    static let pill: CGFloat = 20
}

enum IconSize {
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 28
}

enum StrokeWidth {
    static let hairline: CGFloat = 0.5
    static let border: CGFloat = 1
    static let emphasis: CGFloat = 2
}

enum ChartHeight {
    static let compact: CGFloat = 120
    static let standard: CGFloat = 160
}

enum DashPattern {
    static let projected: [CGFloat] = [4, 4]
    static let goal: [CGFloat] = [2, 4]
}
