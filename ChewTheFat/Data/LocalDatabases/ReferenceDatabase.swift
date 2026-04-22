import Foundation

enum ReferenceDatabaseError: Error, Sendable {
    case fileMissing(URL)
    case grdbUnavailable
}

enum ReferenceDatabaseLocation {
    static func url(forResourceNamed name: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name, withExtension: "sqlite")
    }
}
