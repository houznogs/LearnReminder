import Foundation

final class TaskStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "taskCompletions"
    private let notesKey = "taskNotes"
    private let queue = DispatchQueue(label: "TaskStore.queue", attributes: .concurrent)
    private var completions: [String: Date?] = [:]
    private var notes: [String: String] = [:]

    init() {
        load()
    }

    func completedDate(for id: String) -> Date? {
        queue.sync {
            completions[id] ?? nil
        }
    }

    func markCompleted(id: String) {
        queue.async(flags: .barrier) {
            self.completions[id] = Date()
            self.persist()
        }
    }

    func markIncomplete(id: String) {
        queue.async(flags: .barrier) {
            self.completions[id] = nil
            self.persist()
        }
    }

    func isCompleted(id: String) -> Bool {
        completedDate(for: id) != nil
    }

    func note(for id: String) -> String? {
        queue.sync {
            notes[id]
        }
    }

    func setNote(_ note: String?, for id: String) {
        queue.async(flags: .barrier) {
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                self.notes[id] = trimmed
            } else {
                self.notes.removeValue(forKey: id)
            }
            self.persistNotes()
        }
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Date?].self, from: data) {
            completions = decoded
        }
        if let notesData = defaults.data(forKey: notesKey),
           let decodedNotes = try? JSONDecoder().decode([String: String].self, from: notesData) {
            notes = decodedNotes
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(completions) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func persistNotes() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: notesKey)
    }
}
