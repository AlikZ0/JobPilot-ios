import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportDocument: ExportFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportFilename = "JobPilot-backup"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingImport: Data?
    @State private var importFilename = ""
    @State private var authorizationText = "Проверка…"
    @State private var result: ErrorNotice?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                notificationsSection
                transferSection
                privacySection
                aboutSection
            }
            .navigationTitle("Настройки")
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                contentType: exportType, defaultFilename: exportFilename) { outcome in
                switch outcome {
                case .success: result = ErrorNotice(title: "Готово", detail: "Файл сохранён. Храни резервную копию в безопасном месте.")
                case .failure(let error): result = ErrorNotice(error, title: "Ошибка экспорта")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .commaSeparatedText]) { outcome in
                switch outcome {
                case .success(let url): prepareImport(url)
                case .failure(let error): result = ErrorNotice(error, title: "Не удалось выбрать файл")
                }
            }
            .confirmationDialog("Импортировать данные?", isPresented: $showingImportConfirmation, titleVisibility: .visible) {
                Button("Импортировать, пропустив дубликаты") { runImport() }
                Button("Отмена", role: .cancel) { pendingImport = nil }
            } message: { Text("Файл \(importFilename). Существующие вакансии не будут удалены или перезаписаны. Дубликаты по ID или ссылке пропустятся.") }
            .confirmationDialog("Удалить все данные JobPilot?", isPresented: $showingDeleteConfirmation) {
                Button("Удалить все вакансии и события", role: .destructive) { eraseAll() }
            } message: { Text("Удалятся все локальные записи и запланированные уведомления. Сначала сохрани JSON-резервную копию.") }
            .alert(item: $result) { note in Alert(title: Text(note.title), message: Text(note.detail), dismissButton: .default(Text("Понятно"))) }
            .task { await refreshPermission() }
            .jobScreen()
        }
    }

    private var appearanceSection: some View {
        Section("Оформление") {
            Picker("Тема", selection: $appearance) {
                Text("Система").tag("system")
                Text("Светлая").tag("light")
                Text("Тёмная").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    private var notificationsSection: some View {
        Section("Напоминания") {
            HStack {
                Label("Уведомления", systemImage: "bell")
                Spacer()
                Text(authorizationText).foregroundStyle(.secondary).font(.footnote)
            }
            Button("Разрешить уведомления") {
                Task { @MainActor in
                    do {
                        let granted = try await NotificationService.requestPermission()
                        await refreshPermission()
                        if !granted {
                            result = ErrorNotice(title: "Уведомления отключены", detail: "Открой Настройки iPhone → JobPilot → Уведомления.")
                        }
                    } catch { result = ErrorNotice(error) }
                }
            }
            Text("Напоминание для follow-up приходит в выбранное время, для интервью — за 30 минут. Уже сохранённые записи не теряются при отказе в разрешении.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var transferSection: some View {
        Section("Резервная копия") {
            Button {
                prepareExport(type: .json)
            } label: { Label("Экспорт JSON · все данные", systemImage: "square.and.arrow.up") }
            Button {
                prepareExport(type: .commaSeparatedText)
            } label: { Label("Экспорт CSV · только вакансии", systemImage: "tablecells") }
            Button { showingImporter = true } label: {
                Label("Импортировать JSON или CSV", systemImage: "square.and.arrow.down")
            }
            .disabled(working)
            Text("JSON хранит вакансии, статусы, контакты, задачи и интервью. CSV содержит только вакансии. Для восстановления после переустановки заранее экспортируй JSON.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section("Данные и конфиденциальность") {
            Label("Данные хранятся на устройстве", systemImage: "iphone")
                .foregroundStyle(.secondary)
            Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                Label("Удалить все данные", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Версия", value: "1.0.0")
            Text("JobPilot работает без аккаунта, обязательного интернета и внешней аналитики. Отслеживание откликов выполняется вручную.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func refreshPermission() async {
        let status = await NotificationService.authorizationStatus()
        authorizationText = switch status {
        case .authorized, .provisional, .ephemeral: "Разрешены"
        case .denied: "Запрещены"
        case .notDetermined: "Не настроены"
        @unknown default: "Неизвестно"
        }
    }

    private func prepareExport(type: UTType) {
        do {
            exportType = type
            let data = type == .json ? try DataTransferService.exportJSON(context: modelContext) : try DataTransferService.exportCSV(context: modelContext)
            exportDocument = ExportFileDocument(bytes: data)
            exportFilename = type == .json ? "JobPilot-backup" : "JobPilot-vacancies"
            showingExporter = true
        } catch { result = ErrorNotice(error, title: "Не удалось создать резервную копию") }
    }

    private func prepareImport(_ url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        working = true
        Task {
            defer {
                if gainedAccess { url.stopAccessingSecurityScopedResource() }
                working = false
            }
            do {
                let data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
                guard data.count < 20_000_000 else { throw JobPilotError.invalid("Файл слишком большой (лимит 20 МБ).") }
                let name = url.lastPathComponent
                guard name.lowercased().hasSuffix(".json") || name.lowercased().hasSuffix(".csv") else {
                    throw JobPilotError.invalid("Поддерживаются файлы .json и .csv.")
                }
                pendingImport = data
                importFilename = name
                showingImportConfirmation = true
            } catch { result = ErrorNotice(error, title: "Не удалось открыть файл") }
        }
    }

    private func runImport() {
        guard let data = pendingImport else { return }
        defer { pendingImport = nil }
        do {
            let summary = try (importFilename.lowercased().hasSuffix(".json")
                ? DataTransferService.importJSON(data, into: modelContext)
                : DataTransferService.importCSV(data, into: modelContext))
            result = ErrorNotice(title: "Импорт завершён", detail: summary.details + " Если нужны уведомления, открой и пересохрани соответствующие события.")
        } catch { result = ErrorNotice(error, title: "Ошибка импорта") }
    }

    private func eraseAll() {
        do {
            for item in try modelContext.fetch(FetchDescriptor<StageEvent>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Contact>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<FollowUp>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Interview>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Vacancy>()) { modelContext.delete(item) }
            try modelContext.save()
            NotificationService.cancelAll()
            result = ErrorNotice(title: "Данные удалены", detail: "Локальная база JobPilot очищена.")
        } catch { modelContext.rollback(); result = ErrorNotice(error) }
    }
}
