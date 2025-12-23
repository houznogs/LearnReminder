import Foundation
import Combine

@MainActor
final class DeadlinesViewModel: ObservableObject {
    @Published var calendarURLString: String = AppSettings.calendarURLString()
    @Published var deadlines: [DeadlineItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = ICalService()

    func load() async {
        let urlString = AppSettings.normalizedURLString(calendarURLString)
        guard AppSettings.isValidHTTPURL(urlString) else {
            errorMessage = "Please enter a valid http/https URL."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let all = try await service.fetchDeadlines(from: urlString)
            let now = Date()
            let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
            deadlines = all.filter { $0.dueDate >= now && $0.dueDate <= cutoff }
            AppSettings.setCalendarURLString(urlString)
            AppSettings.setLastFetchDate(Date())
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func saveCalendarURL() {
        let normalized = AppSettings.normalizedURLString(calendarURLString)
        AppSettings.setCalendarURLString(normalized)
    }

    func refresh() async {
        await load()
    }

    var nextDueSummary: String {
        guard let next = deadlines.sorted(by: { $0.dueDate < $1.dueDate }).first else {
            return "No upcoming deadlines"
        }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        let relative = rel.localizedString(for: next.dueDate, relativeTo: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeText = timeFormatter.string(from: next.dueDate)

        let coursePart = next.course == "Unknown" ? "" : "\(next.course) "
        return "Next: \(coursePart)\(next.title) due \(relative) at \(timeText)"
    }
}
