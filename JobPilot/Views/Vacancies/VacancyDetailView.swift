import SwiftUI
import SwiftData

struct VacancyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allStages: [StageEvent]
    @Query private var allContacts: [Contact]
    @Query private var allTasks: [FollowUp]
    @Query private var allInterviews: [Interview]
    let vacancy: Vacancy

    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var showingNewTask = false
    @State private var showingNewInterview = false
    @State private var showingNewContact = false
    @State private var editingTask: FollowUp?
    @State private var editingInterview: Interview?
    @State private var editingContact: Contact?
    @State private var offerFollowUp = false
    @State private var error: ErrorNotice?

    private var stages: [StageEvent] { allStages.filter { $0.vacancyID == vacancy.id }.sorted { $0.date > $1.date } }
    private var tasks: [FollowUp] { allTasks.filter { $0.vacancyID == vacancy.id }.sorted { $0.dueAt < $1.dueAt } }
    private var interviews: [Interview] { allInterviews.filter { $0.vacancyID == vacancy.id }.sorted { $0.at < $1.at } }
    private var contacts: [Contact] { allContacts.filter { $0.vacancyID == vacancy.id }.sorted { $0.name < $1.name } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                statusBlock
                detailsBlock
                tasksBlock
                interviewsBlock
                contactsBlock
                historyBlock
                deleteButton
            }
            .padding(16)
        }
        .navigationTitle(vacancy.company)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Изменить") { showingEdit = true } } }
        .sheet(isPresented: $showingEdit) { NavigationStack { VacancyFormView(vacancy: vacancy) } }
        .sheet(isPresented: $showingNewTask) { NavigationStack { FollowUpFormView(vacancy: vacancy) } }
        .sheet(isPresented: $showingNewInterview) { NavigationStack { InterviewFormView(vacancy: vacancy) } }
        .sheet(isPresented: $showingNewContact) { NavigationStack { ContactFormView(vacancy: vacancy) } }
        .sheet(item: $editingTask) { item in NavigationStack { FollowUpFormView(vacancy: vacancy, original: item) } }
        .sheet(item: $editingInterview) { item in NavigationStack { InterviewFormView(vacancy: vacancy, original: item) } }
        .sheet(item: $editingContact) { item in NavigationStack { ContactFormView(vacancy: vacancy, original: item) } }
        .confirmationDialog("Удалить вакансию и связанные данные?", isPresented: $showingDelete) {
            Button("Удалить всё", role: .destructive) { removeVacancy() }
        } message: { Text("Будут удалены задачи, контакты, история и интервью. Это нельзя отменить.") }
        .confirmationDialog("Напомнить о follow-up?", isPresented: $offerFollowUp, titleVisibility: .visible) {
            Button("Создать задачу через 7 дней") { createSuggestedFollowUp() }
            Button("Выбрать дату вручную") { showingNewTask = true }
            Button("Не сейчас", role: .cancel) {}
        } message: { Text("Напоминание создаётся только с твоего согласия.") }
        .alert(item: $error) { notice in
            Alert(title: Text(notice.title), message: Text(notice.detail), dismissButton: .default(Text("Понятно")))
        }
        .jobScreen()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vacancy.role).font(.largeTitle.bold()).tracking(-0.7)
            Text(vacancy.company).font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 9) {
                if let location = vacancy.location, !location.isEmpty {
                    Label(location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                }
                if vacancy.vacancyPriority == .high {
                    Label("Приоритет", systemImage: "flag.fill").font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var statusBlock: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Текущий статус").font(.caption).foregroundStyle(.secondary)
                        StatusPill(status: vacancy.vacancyStatus)
                    }
                    Spacer()
                    Menu {
                        ForEach(VacancyStatus.allCases) { status in
                            Button {
                                updateStatus(status)
                            } label: {
                                if status == vacancy.vacancyStatus {
                                    Label(status.title, systemImage: "checkmark")
                                } else { Text(status.title) }
                            }
                        }
                    } label: { Label("Изменить", systemImage: "chevron.down").font(.subheadline.weight(.semibold)) }
                }
                Text(vacancy.eligibility.title)
                    .font(.subheadline)
                    .foregroundStyle(vacancy.eligibility == .no ? Color.red : Color.secondary)
                if let applied = vacancy.appliedAt {
                    Label("Отклик: \(applied.formatted(date: .abbreviated, time: .omitted))", systemImage: "paperplane")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Подробности")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    if let salary = vacancy.salaryDisplay { detailLine("Зарплата", value: salary) }
                    if let source = vacancy.source, !source.isEmpty { detailLine("Источник", value: source) }
                    if let urlString = vacancy.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Открыть вакансию", systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    if !vacancy.technologies.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Технологии").font(.caption).foregroundStyle(.secondary)
                            Text(vacancy.technologies.joined(separator: " · ")).font(.subheadline)
                        }
                    }
                    if !vacancy.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Заметки").font(.caption).foregroundStyle(.secondary)
                            Text(vacancy.notes).font(.subheadline).textSelection(.enabled)
                        }
                    }
                    if vacancy.salaryDisplay == nil && vacancy.technologies.isEmpty && vacancy.notes.isEmpty && vacancy.url == nil {
                        Text("Добавь зарплату, требования или заметки через «Изменить».")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }
                }
            }
        }
    }

    private func detailLine(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).multilineTextAlignment(.trailing)
        }
    }

    private var tasksBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Follow-up", action: { showingNewTask = true })
            SurfaceCard {
                if tasks.isEmpty {
                    Text("Нет запланированных follow-up").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 13) {
                        ForEach(tasks) { task in taskRow(task) }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: FollowUp) -> some View {
        HStack(spacing: 10) {
            Button { toggleTask(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(task.isDone ? .green : JobStyle.accent)
            }
            .accessibilityLabel(task.isDone ? "Отметить как невыполненное" : "Отметить как выполненное")
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.subheadline.weight(.medium)).strikethrough(task.isDone)
                Text(task.dueAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Изменить") { editingTask = task }
                Button("Удалить", role: .destructive) { deleteTask(task) }
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                .accessibilityLabel("Действия с задачей")
        }
    }

    private var interviewsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Собеседования", action: { showingNewInterview = true })
            SurfaceCard {
                if interviews.isEmpty {
                    Text("Собеседований пока нет").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 13) {
                        ForEach(interviews) { event in
                            HStack(spacing: 12) {
                                Image(systemName: "video.circle.fill").font(.title2).foregroundStyle(JobStyle.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.at.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold))
                                    Text(InterviewFormat(rawValue: event.format)?.title ?? "Интервью").font(.caption).foregroundStyle(.secondary)
                                    if !event.notes.isEmpty { Text(event.notes).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 0)
                                Menu {
                                    Button("Изменить") { editingInterview = event }
                                    Button("Удалить", role: .destructive) { deleteInterview(event) }
                                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var contactsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Контакты", action: { showingNewContact = true })
            SurfaceCard {
                if contacts.isEmpty {
                    Text("Контакты не добавлены").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 13) {
                        ForEach(contacts) { contact in
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(JobStyle.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.name).font(.subheadline.weight(.semibold))
                                    Text([contact.role, contact.email ?? "", contact.telegram ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Menu {
                                    Button("Изменить") { editingContact = contact }
                                    Button("Удалить", role: .destructive) { deleteContact(contact) }
                                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "История статусов")
            SurfaceCard {
                if stages.isEmpty {
                    Text("Изменений статуса пока нет").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(stages) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(VacancyStatus(rawValue: item.oldStatus)?.title ?? item.oldStatus) → \(VacancyStatus(rawValue: item.newStatus)?.title ?? item.newStatus)")
                                    .font(.subheadline.weight(.medium))
                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            Button(action: action) { Label("Добавить", systemImage: "plus") }.font(.subheadline)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { showingDelete = true } label: {
            Label("Удалить вакансию", systemImage: "trash").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 6)
    }

    private func updateStatus(_ status: VacancyStatus) {
        do {
            let previous = vacancy.vacancyStatus
            try VacancyStore.changeStatus(vacancy, to: status, in: modelContext)
            if previous != .applied && status == .applied { offerFollowUp = true }
        } catch { error = ErrorNotice(error) }
    }

    private func createSuggestedFollowUp() {
        let due = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? Date().addingTimeInterval(604800)
        let task = FollowUp(vacancyID: vacancy.id, title: "Написать рекрутеру", dueAt: due)
        do {
            modelContext.insert(task); try modelContext.save()
            Task { @MainActor in
                do { try await NotificationService.scheduleFollowUp(task, company: vacancy.company) }
                catch { self.error = ErrorNotice(error, title: "Задача сохранена без уведомления") }
            }
        } catch { error = ErrorNotice(error) }
    }

    private func toggleTask(_ task: FollowUp) {
        do {
            task.isDone.toggle()
            try modelContext.save()
            if task.isDone { NotificationService.cancelFollowUp(id: task.id) }
            else {
                Task { @MainActor in
                    do { try await NotificationService.scheduleFollowUp(task, company: vacancy.company) }
                    catch { self.error = ErrorNotice(error, title: "Задача сохранена без уведомления") }
                }
            }
        } catch { modelContext.rollback(); error = ErrorNotice(error) }
    }
    private func deleteTask(_ task: FollowUp) {
        do { NotificationService.cancelFollowUp(id: task.id); modelContext.delete(task); try modelContext.save() }
        catch { error = ErrorNotice(error) }
    }
    private func deleteInterview(_ interview: Interview) {
        do { NotificationService.cancelInterview(id: interview.id); modelContext.delete(interview); try modelContext.save() }
        catch { error = ErrorNotice(error) }
    }
    private func deleteContact(_ contact: Contact) {
        do { modelContext.delete(contact); try modelContext.save() }
        catch { error = ErrorNotice(error) }
    }
    private func removeVacancy() {
        do { try VacancyStore.delete(vacancy, in: modelContext); dismiss() }
        catch { error = ErrorNotice(error) }
    }
}
