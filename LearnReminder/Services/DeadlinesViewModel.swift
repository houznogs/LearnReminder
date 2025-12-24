import Foundation
import Combine

@MainActor
final class DeadlinesViewModel: ObservableObject {
    @Published var calendarURLString: String = AppSettings.calendarURLString()
    @Published var deadlines: [DeadlineItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let localization = LocalizationManager.shared
    private let service = ICalService()
    private let taskStore = TaskStore()

    func load() async {
        let urlString = AppSettings.normalizedURLString(calendarURLString)
        guard AppSettings.isValidHTTPURL(urlString) else {
            errorMessage = localization.localized("error.invalid_url")
            return
        }

        let service = service

        isLoading = true
        errorMessage = nil
        do {
            let all = try await Task.detached(priority: .background) {
                try await service.fetchDeadlines(from: urlString)
            }.value
            deadlines = all
                .map { item in
                    var item = item
                    item.completedAt = taskStore.completedDate(for: item.stableKey)
                    item.notes = taskStore.note(for: item.id)
                    return item
            }
            AppSettings.setCalendarURLString(urlString)
            AppSettings.setLastFetchDate(Date())
        } catch {
            errorMessage = localization.localized("error.sync_failed", error.localizedDescription)
            AppSettings.setLastFetchDate(nil)
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

    var isCalendarLinkValid: Bool {
        AppSettings.isValidHTTPURL(AppSettings.normalizedURLString(calendarURLString))
    }

    var isConnected: Bool {
        isCalendarLinkValid && AppSettings.lastFetchDate() != nil
    }

    var connectionStatusText: String {
        if !isCalendarLinkValid {
            return localization.localized("status.invalid_link")
        }
        return isConnected ? localization.localized("status.connected") : localization.localized("status.not_connected")
    }

    var lastSyncedText: String {
        if let last = AppSettings.lastFetchDate() {
            return localization.relativeDateString(for: last, relativeTo: Date(), unitsStyle: .short)
        }
        return localization.localized("status.never")
    }

    var nextDueSummary: String {
        guard let next = activeDeadlines.sorted(by: { $0.dueDate < $1.dueDate }).first else {
            return localization.localized("summary.no_upcoming")
        }

        let relative = localization.relativeDateString(for: next.dueDate, relativeTo: Date(), unitsStyle: .short)
        let timeText = localization.timeString(for: next.dueDate)

        let coursePart = next.course == DeadlineItem.unknownCoursePlaceholder ? "" : "\(next.course) "
        return localization.localized("summary.next_due", coursePart, next.title, relative, timeText)
    }

    var activeDeadlines: [DeadlineItem] {
        deadlines.filter { !$0.isCompleted }
    }

    var completedDeadlines: [DeadlineItem] {
        deadlines.filter(\.isCompleted)
    }

    func toggleCompletion(for item: DeadlineItem) {
        guard let index = deadlines.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = deadlines[index]

        if updated.isCompleted {
            updated.markIncomplete()
            taskStore.markIncomplete(id: updated.stableKey)
        } else {
            updated.markCompleted()
            taskStore.markCompleted(id: updated.stableKey)
        }

        deadlines[index] = updated
    }

    func updateNotes(for id: String, notes: String?) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }) else { return }
        var updated = deadlines[index]
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = (trimmed?.isEmpty ?? true) ? nil : trimmed
        deadlines[index] = updated
        taskStore.setNote(trimmed, for: updated.id)
    }
}
