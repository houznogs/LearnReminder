import Foundation

struct ICalService {
    func fetchDeadlines(from urlString: String) async throws -> [DeadlineItem] {
        let normalized = AppSettings.normalizedURLString(urlString)
        guard AppSettings.isValidHTTPURL(normalized), let url = URL(string: normalized) else {
            throw ICalServiceError.invalidURL
        }

        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (fetchedData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw ICalServiceError.invalidResponse
            }
            data = fetchedData
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ICalServiceError.unreadableData
        }

        let lines = unfoldICSLines(text)
        var events: [[String: String]] = []
        var current: [String: String] = [:]
        var inEvent = false

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                current = [:]
                continue
            }
            if line == "END:VEVENT" {
                if inEvent {
                    events.append(current)
                }
                inEvent = false
                continue
            }
            guard inEvent else { continue }

            let (key, value) = parsePropertyValue(line)
            guard let key = key, let value = value else { continue }
            current[key] = value
        }

        let now = Date()
        let pastCutoff = Calendar.current.date(byAdding: .day, value: -180, to: now) ?? now
        let futureCutoff = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now

        var unique: [String: DeadlineItem] = [:]

        for fields in events {
            guard let summary = fields["SUMMARY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !summary.isEmpty else { continue }

            let categories = fields["CATEGORIES"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let course = courseName(from: summary, categories: categories)

            let dateString = fields["DUE"] ?? fields["DTEND"] ?? fields["DTSTART"]
            guard let dateString, let dueDate = parseDate(dateString) else { continue }
            guard dueDate >= pastCutoff && dueDate <= futureCutoff else { continue }

            let item = DeadlineItem(
                title: summary,
                course: course,
                dueDate: dueDate,
                sourceURL: fields["URL"]
            )
            unique[item.id] = item
        }

        return unique.values.sorted { $0.dueDate < $1.dueDate }
    }
}

// MARK: - Helpers

private func unfoldICSLines(_ text: String) -> [String] {
    var unfolded: [String] = []
    var current = ""

    for rawLine in text.split(whereSeparator: \.isNewline) {
        let line = String(rawLine)
        if line.hasPrefix(" ") || line.hasPrefix("\t") {
            current += line.dropFirst()
        } else {
            if !current.isEmpty {
                unfolded.append(current)
            }
            current = line
        }
    }
    if !current.isEmpty {
        unfolded.append(current)
    }
    return unfolded
}

private func parsePropertyValue(_ line: String) -> (String?, String?) {
    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return (nil, nil) }
    let key = parts[0].split(separator: ";", maxSplits: 1).first.map { String($0).uppercased() }
    return (key, parts[1])
}

private func parseDate(_ value: String) -> Date? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)

    var dateText = parts.count == 2 ? parts[1] : trimmed
    var timeZone: TimeZone? = nil

    if parts.count == 2 {
        let paramPart = parts[0]
        // Look for TZID=...
        if let range = paramPart.range(of: "TZID=", options: .caseInsensitive) {
            let tzID = String(paramPart[range.upperBound...])
            timeZone = TimeZone(identifier: tzID)
        }
    }

    if dateText.hasSuffix("Z") {
        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmm'Z'"
        ]
        for format in formats {
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = df.date(from: dateText) { return date }
        }
    }

    let localFormats = [
        "yyyyMMdd'T'HHmmss",
        "yyyyMMdd'T'HHmm",
        "yyyyMMdd"
    ]
    for format in localFormats {
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = timeZone ?? TimeZone.current
        if let date = df.date(from: dateText) { return date }
    }

    return nil
}

private func courseName(from summary: String, categories: String?) -> String {
    if let category = categories, !category.isEmpty {
        return category
    }

    let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    // Heuristic: prefix like "ECE 123 - Title"
    if let range = trimmed.range(of: " - ") {
        let prefix = String(trimmed[..<range.lowerBound])
        if looksLikeCourseCode(prefix) {
            return prefix
        }
    }

    return DeadlineItem.unknownCoursePlaceholder
}

private func looksLikeCourseCode(_ text: String) -> Bool {
    let pattern = #"^[A-Za-z]{2,4}\s*\d{2,3}[A-Za-z]?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.firstMatch(in: text, options: [], range: range) != nil
}

// MARK: - Errors

enum ICalServiceError: Error {
    case invalidURL
    case unreadableData
    case invalidResponse
}
