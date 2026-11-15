import ConvexMobile
import Foundation

struct Moment: Decodable, Identifiable, Equatable {
    let id: String
    let text: String
    let author: String
    @ConvexFloat var createdAt: Double

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case author
        case createdAt
    }
}
