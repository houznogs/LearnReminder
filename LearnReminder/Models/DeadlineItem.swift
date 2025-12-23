import Foundation
import CryptoKit

struct DeadlineItem: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let course: String
    let dueDate: Date
    let sourceURL: String?

    init(id: String? = nil, title: String, course: String, dueDate: Date, sourceURL: String? = nil) {
        self.title = title
        self.course = course
        self.dueDate = dueDate
        self.sourceURL = sourceURL
        self.id = id ?? DeadlineItem.makeStableID(title: title, course: course, dueDate: dueDate, sourceURL: sourceURL)
    }

    var isOverdue: Bool {
        dueDate < Date()
    }

    var relativeDueText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }

    private static func makeStableID(title: String, course: String, dueDate: Date, sourceURL: String?) -> String {
        let components: [String] = [
            title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            course.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            ISO8601DateFormatter().string(from: dueDate),
            sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        ]
        let joined = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
