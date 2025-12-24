import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: DeadlinesViewModel
    @State private var searchText: String = ""
    @State private var selectedCourse: String?
    @EnvironmentObject private var localization: LocalizationManager
    @FocusState private var searchFocused: Bool
    @State private var filteredActive: [DeadlineItem] = []
    @State private var filteredCompletedState: [DeadlineItem] = []
    @State private var filterGeneration: Int = 0

    var body: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if let error = vm.errorMessage, !error.isEmpty {
                errorView(message: error)
            } else if vm.isCalendarLinkValid && vm.activeDeadlines.isEmpty {
                emptyStateView
            } else {
                dashboardContent
            }
        }
        .navigationTitle(localization.localized("dashboard.title"))
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: localization.localized("search.placeholder"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                courseMenu
            }
        }
        .onAppear { refreshFilters() }
        .onChange(of: vm.deadlines) { _ in refreshFilters() }
        .onChange(of: searchText) { _ in refreshFilters() }
        .onChange(of: selectedCourse) { _ in refreshFilters() }
    }

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                nextDueCard

                filterRow

                section(title: localization.localized("dashboard.section_due_today")) {
                    if dueToday.isEmpty {
                        Text(localization.localized("dashboard.empty_today"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dueToday) { item in
                                DeadlineRow(item: item) {
                                    vm.toggleCompletion(for: item)
                                }
                            }
                        }
                    }
                }

                section(title: localization.localized("dashboard.section_this_week")) {
                    if thisWeek.isEmpty {
                        Text(localization.localized("dashboard.empty_week"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(thisWeek.prefix(10))) { item in
                                DeadlineRow(item: item) {
                                    vm.toggleCompletion(for: item)
                                }
                            }
                        }
                    }
                }

                section(title: localization.localized("dashboard.section_all")) {
                    if filteredActiveDeadlines.isEmpty {
                        Text(localization.localized("dashboard.empty_upcoming"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredActiveDeadlines) { item in
                                DeadlineRow(item: item) {
                                    vm.toggleCompletion(for: item)
                                }
                            }
                        }
                    }
                }

                if !filteredCompleted.isEmpty {
                    section(title: localization.localized("dashboard.section_completed")) {
                        VStack(spacing: 8) {
                            ForEach(filteredCompleted.prefix(5)) { item in
                                DeadlineRow(item: item) {
                                    vm.toggleCompletion(for: item)
                                }
                            }
                            if filteredCompleted.count > 5 {
                                Text(localization.localized("dashboard.more_completed", filteredCompleted.count - 5))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .dismissKeyboardOnTap()
    }

    private var nextDueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.localized("dashboard.next_due_title"))
                .font(.headline)
                .foregroundStyle(.secondary)
            if let item = nextDue {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayCourse(item.course))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 10) {
                        Label(localization.shortDateTimeString(for: item.dueDate), systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(item.relativeDueText)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.2)))
                            .foregroundStyle(.white)
                        if item.isOverdue {
                            Text(localization.localized("label.overdue"))
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.2)))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    LinearGradient(colors: [Color.indigo.opacity(0.9), Color.blue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.localized("dashboard.no_upcoming_card"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(localization.localized("dashboard.connect_prompt"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
            }
        }
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            Menu {
                Button(localization.localized("filter.all")) { selectedCourse = nil }
                ForEach(availableCourses, id: \.self) { course in
                    Button {
                        selectedCourse = course
                    } label: {
                        if selectedCourse == course {
                            Label(displayCourse(course), systemImage: "checkmark")
                        } else {
                            Text(displayCourse(course))
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(localization.localized("filter.course"))
                    Text(selectedCourse.map(displayCourse) ?? localization.localized("filter.all"))
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator)))
            }
            Spacer()
        }
    }

    private var courseMenu: some View {
        Menu {
            Button(localization.localized("filter.all")) { selectedCourse = nil }
            ForEach(availableCourses, id: \.self) { course in
                Button {
                    selectedCourse = course
                } label: {
                    if selectedCourse == course {
                        Label(displayCourse(course), systemImage: "checkmark")
                    } else {
                        Text(displayCourse(course))
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private var filteredActiveDeadlines: [DeadlineItem] {
        filteredActive
    }

    private var filteredCompleted: [DeadlineItem] {
        filteredCompletedState
    }

    private var dueToday: [DeadlineItem] {
        filteredActiveDeadlines.filter { Calendar.current.isDateInToday($0.dueDate) }
    }

    private var thisWeek: [DeadlineItem] {
        let todayIDs = Set(dueToday.map(\.id))
        return filteredActiveDeadlines.filter { item in
            let inWindow = isWithinNextWeek(item.dueDate)
            return inWindow && !todayIDs.contains(item.id)
        }
    }

    private var nextDue: DeadlineItem? {
        let now = Date()
        return filteredActiveDeadlines
            .filter { $0.dueDate >= now }
            .sorted { $0.dueDate < $1.dueDate }
            .first
    }

    private var availableCourses: [String] {
        Array(Set(vm.activeDeadlines.map(\.course))).sorted()
    }

    private func matchesCourse(_ item: DeadlineItem) -> Bool {
        guard let course = selectedCourse else { return true }
        return item.course == course
    }

    private func matchesSearch(_ item: DeadlineItem) -> Bool {
        guard !searchText.isEmpty else { return true }
        let needle = searchText.lowercased()
        return item.title.lowercased().contains(needle) || item.course.lowercased().contains(needle)
    }

    private func isWithinNextWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        guard
            let start = calendar.dateInterval(of: .day, for: now)?.start,
            let end = calendar.date(byAdding: .day, value: 7, to: start)
        else { return false }
        return date >= start && date <= end
    }

    private func refreshFilters() {
        filterGeneration += 1
        let generation = filterGeneration
        let search = searchText.lowercased()
        let course = selectedCourse
        let deadlines = vm.deadlines

        DispatchQueue.global(qos: .userInitiated).async {
            let matches: (DeadlineItem) -> Bool = { item in
                if let course, item.course != course { return false }
                guard !search.isEmpty else { return true }
                let haystack = "\(item.title) \(item.course)".lowercased()
                return haystack.contains(search)
            }

            let active = deadlines
                .filter { !$0.isCompleted && matches($0) }
                .sorted { $0.dueDate < $1.dueDate }
            let completed = deadlines
                .filter { $0.isCompleted && matches($0) }
                .sorted { ($0.dueDate) > ($1.dueDate) }

            DispatchQueue.main.async {
                guard generation == filterGeneration else { return }
                filteredActive = active
                filteredCompletedState = completed
            }
        }
    }

    private func displayCourse(_ course: String) -> String {
        course == DeadlineItem.unknownCoursePlaceholder ? localization.localized("course.unknown") : course
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(localization.localized("loading.syncing"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(localization.localized("error.fetch_title"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.refresh() }
            } label: {
                Label(localization.localized("action.try_again"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(localization.localized("empty_state.title"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(localization.localized("empty_state.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
}

#Preview {
    DashboardView(vm: DeadlinesViewModel())
        .environmentObject(LocalizationManager.shared)
}
