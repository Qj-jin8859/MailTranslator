import Foundation

struct MailSnapshot: Equatable {
    let messageID: String
    let subject: String
    let sender: String
    let body: String
    let source: String

    var detectionText: String {
        "\(subject)\n\n\(body)"
    }
}
