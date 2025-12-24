import Foundation
import CryptoKit

struct DeadlineItem: Identifiable, Hashable, Codable {
    static let unknownCoursePlaceholder = "Unknown"
    let id: String
    let title: String
    let course: String
    let dueDate: Date
    let sourceURL: String?
    var completedAt: Date?
    var notes: String?

    var stableKey: String {
        DeadlineItem.makeStableKey(title: title, course: course, dueDate: dueDate)
    }

    init(
        id: String? = nil,
        title: String,
        course: String,
        dueDate: Date,
        sourceURL: String? = nil,
        completedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.course = course
        self.dueDate = dueDate
        self.sourceURL = sourceURL
        self.completedAt = completedAt
        self.notes = notes
        self.id = id ?? DeadlineItem.makeStableID(title: title, course: course, dueDate: dueDate, sourceURL: sourceURL)
    }

    var isOverdue: Bool {
        dueDate < Date()
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var relativeDueText: String {
        LocalizationManager.shared.relativeDateString(for: dueDate)
    }

    mutating func markCompleted(at date: Date = Date()) {
        completedAt = date
    }

    mutating func markIncomplete() {
        completedAt = nil
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

    private static func makeStableKey(title: String, course: String, dueDate: Date) -> String {
        func normalize(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let dateText = ISO8601DateFormatter().string(from: dueDate)
        return [normalize(course), normalize(title), dateText].joined(separator: "|")
    }
}
