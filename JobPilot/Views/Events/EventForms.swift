import SwiftUI
import SwiftData

struct FollowUpFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vacancy: Vacancy
    let original: FollowUp?
    @State private var title: String
    @State private var dueAt: Date
    @State private var isDone: Bool
    @State private var error: ErrorNotice?

    init(vacancy: Vacancy, original: FollowUp? = nil) {
        self.vacancy = vacancy; self.original = original
        _title = State(initialValue: original?.title ?? "Написать рекрутеру")
        _dueAt = State(initialValue: original?.dueAt ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now)
        _isDone = State(initialValue: original?.isDone ?? false)
    }

    var body: some View {
        Form {
            Section("Задача") {
                TextField("Что нужно сделать", text: $title)
                DatePicker("Когда", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                Toggle("Выполнено", isOn: $isDone)
            }
            Section { Text("Напоминание запланируется после разрешения уведомлений. Если разрешение отключено, задача всё равно сохранится.")
                .font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle(original == nil ? "Новая задача" : "Изменить задачу")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.bold() }
        }
        .alert(item: $error) { note in Alert(title: Text(note.title), message: Text(note.detail), dismissButton: .default(Text("Понятно"))) }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = ErrorNotice(title: "Пустая задача", detail: "Укажи название задачи."); return
        }
        let task = original ?? FollowUp(vacancyID: vacancy.id, title: title, dueAt: dueAt)
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueAt = dueAt; task.isDone = isDone
        do {
            if original == nil { modelContext.insert(task) }
            try modelContext.save()
            if isDone { NotificationService.cancelFollowUp(id: task.id) }
            else {
                Task { @MainActor in
                    do { try await NotificationService.scheduleFollowUp(task, company: vacancy.company) }
                    catch { NotificationService.cancelFollowUp(id: task.id) }
                }
            }
            dismiss()
        } catch { error = ErrorNotice(error) }
    }
}

struct InterviewFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vacancy: Vacancy
    let original: Interview?
    @State private var at: Date
    @State private var format: InterviewFormat
    @State private var notes: String
    @State private var error: ErrorNotice?

    init(vacancy: Vacancy, original: Interview? = nil) {
        self.vacancy = vacancy; self.original = original
        _at = State(initialValue: original?.at ?? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
        _format = State(initialValue: InterviewFormat(rawValue: original?.format ?? "") ?? .online)
        _notes = State(initialValue: original?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Собеседование") {
                DatePicker("Дата и время", selection: $at, displayedComponents: [.date, .hourAndMinute])
                Picker("Формат", selection: $format) {
                    ForEach(InterviewFormat.allCases) { value in Text(value.title).tag(value) }
                }
                TextField("Место, ссылка, детали", text: $notes, axis: .vertical).lineLimit(3...6)
            }
            Section { Text("Уведомление за 30 минут до встречи, если уведомления разрешены.")
                .font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle(original == nil ? "Новое интервью" : "Изменить интервью")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.bold() }
        }
        .alert(item: $error) { note in Alert(title: Text(note.title), message: Text(note.detail), dismissButton: .default(Text("Понятно"))) }
    }

    private func save() {
        let item = original ?? Interview(vacancyID: vacancy.id, at: at)
        item.at = at; item.format = format.rawValue; item.notes = notes
        do {
            if original == nil { modelContext.insert(item) }
            try modelContext.save()
            Task { @MainActor in
                do { try await NotificationService.scheduleInterview(item, company: vacancy.company) }
                catch { NotificationService.cancelInterview(id: item.id) }
            }
            dismiss()
        } catch { error = ErrorNotice(error) }
    }
}

struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vacancy: Vacancy
    let original: Contact?
    @State private var name: String
    @State private var role: String
    @State private var email: String
    @State private var telegram: String
    @State private var error: ErrorNotice?

    init(vacancy: Vacancy, original: Contact? = nil) {
        self.vacancy = vacancy; self.original = original
        _name = State(initialValue: original?.name ?? "")
        _role = State(initialValue: original?.role ?? "")
        _email = State(initialValue: original?.email ?? "")
        _telegram = State(initialValue: original?.telegram ?? "")
    }

    var body: some View {
        Form {
            Section("Контакт") {
                TextField("Имя *", text: $name)
                TextField("Роль (HR, рекрутер)", text: $role)
                TextField("Email", text: $email).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Telegram", text: $telegram)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        }
        .navigationTitle(original == nil ? "Новый контакт" : "Изменить контакт")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.bold() }
        }
        .alert(item: $error) { note in Alert(title: Text(note.title), message: Text(note.detail), dismissButton: .default(Text("Понятно"))) }
    }
    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = ErrorNotice(title: "Пустое имя", detail: "Введи имя контакта."); return
        }
        let emailValue = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailParts = emailValue.split(separator: "@", omittingEmptySubsequences: false)
        if !emailValue.isEmpty && (emailParts.count != 2 || emailParts[0].isEmpty || !emailParts[1].contains(".")) {
            error = ErrorNotice(title: "Неверный email", detail: "Проверь адрес почты."); return
        }
        let item = original ?? Contact(vacancyID: vacancy.id, name: name)
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.role = role.trimmingCharacters(in: .whitespacesAndNewlines)
        item.email = email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines)
        item.telegram = telegram.isEmpty ? nil : telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if original == nil { modelContext.insert(item) }
            try modelContext.save(); dismiss()
        } catch { error = ErrorNotice(error) }
    }
}
