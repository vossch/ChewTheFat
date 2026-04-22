import SwiftUI

enum Typography {
    static let largeTitle: Font = .largeTitle
    static let title: Font = .title
    static let title2: Font = .title2
    static let title3: Font = .title3
    static let headline: Font = .headline
    static let body: Font = .body
    static let bodyEmphasized: Font = .body.weight(.semibold)
    static let callout: Font = .callout
    static let subheadline: Font = .subheadline
    static let footnote: Font = .footnote
    static let caption: Font = .caption
    static let caption2: Font = .caption2

    static let monoBody: Font = .body.monospacedDigit()
    static let monoCallout: Font = .callout.monospacedDigit()
}
