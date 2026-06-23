import Foundation

struct ChapterMarker: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var timestamp: TimeInterval

    init(id: UUID = UUID(), title: String, timestamp: TimeInterval) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
    }
}
