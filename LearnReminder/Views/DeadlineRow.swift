import SwiftUI

struct DeadlineRow: View {
    let item: DeadlineItem
    let onToggleComplete: () -> Void
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                onToggleComplete()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(courseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                Text(localization.localized("deadline.date_and_relative", localization.shortDateTimeString(for: item.dueDate), item.relativeDueText))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if item.isOverdue && !item.isCompleted {
                    Text(localization.localized("label.overdue"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if item.isCompleted {
                Button {
                    onToggleComplete()
                } label: {
                    Label(localization.localized("action.undo"), systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)
            } else {
                Button {
                    onToggleComplete()
                } label: {
                    Label(localization.localized("action.complete"), systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .leading) {
            if item.isCompleted {
                Button {
                    onToggleComplete()
                } label: {
                    Label(localization.localized("action.undo"), systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)
            } else {
                Button {
                    onToggleComplete()
                } label: {
                    Label(localization.localized("action.complete"), systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
    }
}

#Preview {
    let sample = DeadlineItem(
        title: "Assignment 1",
        course: "CS 246",
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    )
    return DeadlineRow(item: sample, onToggleComplete: {})
        .padding()
        .environmentObject(LocalizationManager.shared)
}

private extension DeadlineRow {
    var courseText: String {
        item.course == DeadlineItem.unknownCoursePlaceholder ? localization.localized("course.unknown") : item.course
    }
}
