import SwiftUI
import SwiftData

struct EventsView: View {
    @Query private var vacancies: [Vacancy]
    @Query private var interviews: [Interview]
    @Query private var followUps: [FollowUp]
    @State private var selectedDate = Date()
    @State private var showAllUpcoming = true

    private var tasksOnDay: [FollowUp] {
        followUps.filter { Calendar.current.isDate($0.dueAt, inSameDayAs: selectedDate) }
            .sorted { $0.dueAt < $1.dueAt }
    }
    private var interviewsOnDay: [Interview] {
        interviews.filter { Calendar.current.isDate($0.at, inSameDayAs: selectedDate) }
            .sorted { $0.at < $1.at }
    }
    private var upcomingTasks: [FollowUp] {
        followUps.filter { !$0.isDone && $0.dueAt >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.dueAt < $1.dueAt }
    }
    private var upcomingInterviews: [Interview] {
        interviews.filter { $0.at >= .now }.sorted { $0.at < $1.at }
    }
    private func vacancy(_ id: UUID) -> Vacancy? { vacancies.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SurfaceCard {
                        DatePicker("Дата", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(JobStyle.accent)
                    }
                    dayContent
                    upcomingContent
                }
                .padding(16)
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .jobScreen()
        }
    }

    private var dayContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: selectedDate.formatted(.dateTime.day().month(.wide).year()), subtitle: "События в выбранный день")
            if tasksOnDay.isEmpty && interviewsOnDay.isEmpty {
                SurfaceCard { PlaceholderView(symbol: "calendar", title: "Нет событий", message: "Создай интервью или follow-up в карточке вакансии.") }
            } else {
                ForEach(tasksOnDay) { task in
                    if let vacancy = vacancy(task.vacancyID) {
                        NavigationLink { VacancyDetailView(vacancy: vacancy) } label: {
                            eventRow("Follow-up · \(vacancy.company)", detail: task.title, date: task.dueAt,
                                     symbol: task.isDone ? "checkmark.circle" : "bell", done: task.isDone)
                        }.buttonStyle(.plain)
                    }
                }
                ForEach(interviewsOnDay) { interview in
                    if let vacancy = vacancy(interview.vacancyID) {
                        NavigationLink { VacancyDetailView(vacancy: vacancy) } label: {
                            eventRow("Интервью · \(vacancy.company)", detail: InterviewFormat(rawValue: interview.format)?.title ?? "Собеседование",
                                     date: interview.at, symbol: "person.2", done: false)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var upcomingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeading(title: "Ближайшие события", subtitle: "Запланированные действия")
                Spacer()
                Button(showAllUpcoming ? "Скрыть" : "Показать") { showAllUpcoming.toggle() }
                    .font(.subheadline)
            }
            if showAllUpcoming {
                if upcomingTasks.isEmpty && upcomingInterviews.isEmpty {
                    Text("Нет предстоящих событий").font(.subheadline).foregroundStyle(.secondary).padding(12)
                } else {
                    ForEach(upcomingTasks.prefix(10)) { task in
                        if let vacancy = vacancy(task.vacancyID) {
                            NavigationLink { VacancyDetailView(vacancy: vacancy) } label: {
                                eventRow("\(vacancy.company) · follow-up", detail: task.title, date: task.dueAt, symbol: "bell", done: false)
                            }.buttonStyle(.plain)
                        }
                    }
                    ForEach(upcomingInterviews.prefix(10)) { item in
                        if let vacancy = vacancy(item.vacancyID) {
                            NavigationLink { VacancyDetailView(vacancy: vacancy) } label: {
                                eventRow("\(vacancy.company) · интервью", detail: InterviewFormat(rawValue: item.format)?.title ?? "Интервью", date: item.at, symbol: "video", done: false)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ title: String, detail: String, date: Date, symbol: String, done: Bool) -> some View {
        SurfaceCard {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(done ? Color.green : JobStyle.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
