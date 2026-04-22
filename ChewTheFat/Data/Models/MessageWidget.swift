import Foundation
import SwiftData

@Model
final class MessageWidget {
    @Attribute(.unique) var id: UUID
    var order: Int
    var type: String
    var payload: Data

    var message: Message?

    init(
        id: UUID = UUID(),
        order: Int,
        type: String,
        payload: Data,
        message: Message? = nil
    ) {
        self.id = id
        self.order = order
        self.type = type
        self.payload = payload
        self.message = message
    }
}
