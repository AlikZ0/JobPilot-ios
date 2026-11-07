import SwiftUI
import SwiftData

struct VacancyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existing: [Vacancy]
    @State private var draft: VacancyDraft
    @State private var error: ErrorNotice?
    @State private var showingDuplicate = false
    @State private var duplicate: Vacancy?
    let vacancy: Vacancy?

    init(vacancy: Vacancy? = nil) {
        self.vacancy = vacancy
        _draft = State(initialValue: vacancy.map(VacancyDraft.init) ?? VacancyDraft())
    }

    var body: some View {
        Form {
            generalSection
            salarySection
            detailsSection
            notesSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(vacancy == nil ? "Новая вакансия" : "Редактировать")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { attemptSave() }.bold() }
        }
        .alert(item: $error) { notice in
            Alert(title: Text(notice.title), message: Text(notice.detail), dismissButton: .default(Text("Понятно")))
        }
        .confirmationDialog("Похожая вакансия уже есть", isPresented: $showingDuplicate, titleVisibility: .visible) {
            if vacancy == nil {
                Button("Объединить без изменения статуса") { save(merge: true) }
                Button("Создать отдельную запись") { save(merge: false) }
            } else {
                Button("Сохранить несмотря на совпадение") { save(merge: false) }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Ссылка совпадает с вакансией «\(duplicate?.company ?? "")». Объединение заполнит только пустые поля и добавит новые заметки/технологии.")
        }
    }

    private var generalSection: some View {
        Section("Вакансия") {
            TextField("Компания *", text: $draft.company)
                .textInputAutocapitalization(.words)
            TextField("Должность *", text: $draft.role)
            TextField("Ссылка на вакансию", text: $draft.url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Локация", text: $draft.location)
            Picker("Удалённая работа из Армении", selection: $draft.remote) {
                ForEach(RemoteEligibility.allCases) { value in Text(value.title).tag(value) }
            }
            Picker("Приоритет", selection: $draft.priority) {
                ForEach(VacancyPriority.allCases) { value in Text(value.title).tag(value) }
            }
        }
    }

    private var salarySection: some View {
        Section("Зарплата") {
            HStack {
                TextField("От", text: $draft.salaryMin).keyboardType(.decimalPad)
                Text("–").foregroundStyle(.secondary)
                TextField("До", text: $draft.salaryMax).keyboardType(.decimalPad)
            }
            Picker("Валюта", selection: $draft.currency) {
                ForEach(["USD", "AMD", "RUB", "EUR", "GEL", "GBP"], id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var detailsSection: some View {
        Section("Требования") {
            TextField("Стек (React, TypeScript, Vue)", text: $draft.technologies, axis: .vertical)
                .lineLimit(2...4)
            TextField("Источник (сайт, канал и т. д.)", text: $draft.source)
        }
    }

    private var notesSection: some View {
        Section {
            TextEditor(text: $draft.notes)
                .frame(minHeight: 110)
                .accessibilityLabel("Заметки по вакансии")
        } header: { Text("Заметки") } footer: {
            Text("Ссылка вводится вручную. Данные с сайтов автоматически не загружаются.")
        }
    }

    private func attemptSave() {
        do {
            let record = try ValidationService.validated(draft)
            duplicate = existing.first {
                $0.id != vacancy?.id && record.url != nil &&
                    $0.url.flatMap(ValidationService.normalizedURL) == record.url
            }
            if duplicate != nil { showingDuplicate = true }
            else { save(merge: false) }
        } catch { self.error = ErrorNotice(error, title: "Проверь данные") }
    }

    private func save(merge: Bool) {
        do {
            let valid = try ValidationService.validated(draft)
            if merge, let duplicate { try VacancyStore.merge(valid, into: duplicate, in: modelContext) }
            else if let vacancy { try VacancyStore.update(vacancy, with: valid, in: modelContext) }
            else { _ = try VacancyStore.create(valid, in: modelContext) }
            dismiss()
        } catch { error = ErrorNotice(error) }
    }
}
