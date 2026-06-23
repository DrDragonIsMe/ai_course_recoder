import Foundation

/// A slide or scene item shown in the left deck of the studio layout.
struct SlideItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var pageNumber: Int
    var imageData: Data?

    init(id: UUID = UUID(), title: String, pageNumber: Int, imageData: Data? = nil) {
        self.id = id
        self.title = title
        self.pageNumber = pageNumber
        self.imageData = imageData
    }
}
