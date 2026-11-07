import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VacancyRecord: Codable {
    let id: UUID
    var company: String
    var role: String
    var url: String?
    var salaryMin: Double?
    var salaryMax: Double?
    var currency: String?
    var location: String?
    var remoteEligibility: String
    var status: String
    var priority: Int
    var technologies: [String]
    var source: String?
    var createdAt: Date
    var appliedAt: Date?
    var updatedAt: Date
    var notes: String

    init(_ vacancy: Vacancy) {
        id = vacancy.id; company = vacancy.company; role = vacancy.role
        url = vacancy.url; salaryMin = vacancy.salaryMin; salaryMax = vacancy.salaryMax
        currency = vacancy.currency; location = vacancy.location
        remoteEligibility = vacancy.remoteEligibility; status = vacancy.status; priority = vacancy.priority
        technologies = vacancy.technologies; source = vacancy.source; createdAt = vacancy.createdAt
        appliedAt = vacancy.appliedAt; updatedAt = vacancy.updatedAt; notes = vacancy.notes
    }

    func model() -> Vacancy {
        Vacancy(id: id, company: company, role: role, url: url, salaryMin: salaryMin,
            salaryMax: salaryMax, currency: currency, location: location, remoteEligibility: remoteEligibility,
            status: status, priority: priority, technologies: technologies, source: source,
            createdAt: createdAt, appliedAt: appliedAt, updatedAt: updatedAt, notes: notes)
    }
}

struct StageEventRecord: Codable {
    let id: UUID; let vacancyID: UUID; let oldStatus: String; let newStatus: String; let date: Date
    init(_ m: StageEvent) { id = m.id; vacancyID = m.vacancyID; oldStatus = m.oldStatus; newStatus = m.newStatus; date = m.date }
    func model() -> StageEvent { StageEvent(id: id, vacancyID: vacancyID, oldStatus: oldStatus, newStatus: newStatus, date: date) }
}
struct ContactRecord: Codable {
    let id: UUID; let vacancyID: UUID; let name: String; let role: String; let email: String?; let telegram: String?
    init(_ m: Contact) { id = m.id; vacancyID = m.vacancyID; name = m.name; role = m.role; email = m.email; telegram = m.telegram }
    func model() -> Contact { Contact(id: id, vacancyID: vacancyID, name: name, role: role, email: email, telegram: telegram) }
}
struct FollowUpRecord: Codable {
    let id: UUID; let vacancyID: UUID; let title: String; let dueAt: Date; let isDone: Bool
    init(_ m: FollowUp) { id = m.id; vacancyID = m.vacancyID; title = m.title; dueAt = m.dueAt; isDone = m.isDone }
    func model() -> FollowUp { FollowUp(id: id, vacancyID: vacancyID, title: title, dueAt: dueAt, isDone: isDone) }
}
struct InterviewRecord: Codable {
    let id: UUID; let vacancyID: UUID; let at: Date; let format: String; let notes: String
    init(_ m: Interview) { id = m.id; vacancyID = m.vacancyID; at = m.at; format = m.format; notes = m.notes }
    func model() -> Interview { Interview(id: id, vacancyID: vacancyID, at: at, format: format, notes: notes) }
}

struct JobPilotBackup: Codable {
    var version = 1
    var exportedAt = Date()
    var vacancies: [VacancyRecord]
    var stageEvents: [StageEventRecord]
    var contacts: [ContactRecord]
    var followUps: [FollowUpRecord]
    var interviews: [InterviewRecord]
}

struct ImportSummary {
    var vacanciesAdded: Int = 0
    var duplicatesSkipped: Int = 0
    var relatedRecordsAdded: Int = 0
    var details: String {
        "Добавлено вакансий: \(vacanciesAdded). Пропущено дубликатов: \(duplicatesSkipped). Связанных записей: \(relatedRecordsAdded)."
    }
}

struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else {
            throw JobPilotError.invalid("Не удалось открыть файл.")
        }
        self.bytes = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }
}

enum CSVCodec {
    static let headers = ["id", "company", "role", "url", "salaryMin", "salaryMax", "currency", "location", "remoteEligibility", "status", "priority", "technologies", "source", "createdAt", "appliedAt", "updatedAt", "notes"]

    static func escape(_ input: String) -> String {
        if input.contains(",") || input.contains("\"") || input.contains("\n") || input.contains("\r") {
            return "\"" + input.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return input
    }

    static func encode(_ rows: [[String]]) -> String {
        rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func decode(_ text: String) throws -> [[String]] {
        let chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        var result: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var afterQuote = false
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if quoted {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; afterQuote = true }
                } else { field.append(ch) }
            } else if afterQuote {
                if ch == "," { row.append(field); field = ""; afterQuote = false }
                else if ch == "\n" || ch == "\r" {
                    row.append(field); result.append(row); field = ""; row = []; afterQuote = false
                    if ch == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                } else { throw JobPilotError.invalid("Некорректный CSV: символ после закрывающей кавычки.") }
            } else if ch == "\"" {
                guard field.isEmpty else { throw JobPilotError.invalid("Некорректный CSV: кавычки внутри поля.") }
                quoted = true
            } else if ch == "," {
                row.append(field); field = ""
            } else if ch == "\n" || ch == "\r" {
                row.append(field); result.append(row); row = []; field = ""
                if ch == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else { field.append(ch) }
            i += 1
        }
        guard !quoted else { throw JobPilotError.invalid("Некорректный CSV: незакрытые кавычки.") }
        if afterQuote || !row.isEmpty || !field.isEmpty { row.append(field); result.append(row) }
        return result
    }
}

@MainActor
enum DataTransferService {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func exportJSON(context: ModelContext) throws -> Data {
        let backup = JobPilotBackup(
            vacancies: try context.fetch(FetchDescriptor<Vacancy>()).map(VacancyRecord.init),
            stageEvents: try context.fetch(FetchDescriptor<StageEvent>()).map(StageEventRecord.init),
            contacts: try context.fetch(FetchDescriptor<Contact>()).map(ContactRecord.init),
            followUps: try context.fetch(FetchDescriptor<FollowUp>()).map(FollowUpRecord.init),
            interviews: try context.fetch(FetchDescriptor<Interview>()).map(InterviewRecord.init)
        )
        return try encoder().encode(backup)
    }

    static func exportCSV(context: ModelContext) throws -> Data {
        let iso = ISO8601DateFormatter()
        let rows = try context.fetch(FetchDescriptor<Vacancy>()).map { v in
            [v.id.uuidString, v.company, v.role, v.url ?? "", v.salaryMin.map { String($0) } ?? "", v.salaryMax.map { String($0) } ?? "", v.currency ?? "", v.location ?? "", v.remoteEligibility, v.status, String(v.priority), v.technologies.joined(separator: ";"), v.source ?? "", iso.string(from: v.createdAt), v.appliedAt.map(iso.string(from:)) ?? "", iso.string(from: v.updatedAt), v.notes]
        }
        return Data(CSVCodec.encode([CSVCodec.headers] + rows).utf8)
    }

    static func importJSON(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        let backup = try decoder().decode(JobPilotBackup.self, from: data)
        guard backup.version == 1 else { throw JobPilotError.unsupported("Версия резервной копии не поддерживается.") }
        let identifiers = backup.vacancies.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw JobPilotError.invalid("В резервной копии повторяются идентификаторы вакансий.")
        }
        let validIDs = Set(identifiers)
        for v in backup.vacancies {
            guard !v.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !v.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw JobPilotError.invalid("В резервной копии есть вакансия без компании или должности.")
            }
            if let url = v.url, !url.isEmpty, ValidationService.normalizedURL(url) == nil {
                throw JobPilotError.invalid("В резервной копии есть неправильная ссылка.")
            }
        }
        let refs = backup.stageEvents.map(\.vacancyID) + backup.contacts.map(\.vacancyID) + backup.followUps.map(\.vacancyID) + backup.interviews.map(\.vacancyID)
        guard refs.allSatisfy({ validIDs.contains($0) }) else {
            throw JobPilotError.invalid("Резервная копия содержит записи без вакансий.")
        }
        let existing = try context.fetch(FetchDescriptor<Vacancy>())
        var ids = Set(existing.map(\.id))
        var urls = Set(existing.compactMap { $0.url.flatMap(ValidationService.normalizedURL) })
        var inserted: Set<UUID> = []
        var summary = ImportSummary()
        do {
            for record in backup.vacancies {
                let url = record.url.flatMap(ValidationService.normalizedURL)
                if ids.contains(record.id) || (url != nil && urls.contains(url!)) {
                    summary.duplicatesSkipped += 1; continue
                }
                context.insert(record.model())
                ids.insert(record.id)
                if let url { urls.insert(url) }
                inserted.insert(record.id)
                summary.vacanciesAdded += 1
            }
            for record in backup.stageEvents where inserted.contains(record.vacancyID) {
                context.insert(record.model()); summary.relatedRecordsAdded += 1
            }
            for record in backup.contacts where inserted.contains(record.vacancyID) {
                context.insert(record.model()); summary.relatedRecordsAdded += 1
            }
            for record in backup.followUps where inserted.contains(record.vacancyID) {
                context.insert(record.model()); summary.relatedRecordsAdded += 1
            }
            for record in backup.interviews where inserted.contains(record.vacancyID) {
                context.insert(record.model()); summary.relatedRecordsAdded += 1
            }
            try context.save()
        } catch { context.rollback(); throw error }
        return summary
    }

    static func importCSV(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        guard let string = String(data: data, encoding: .utf8) else {
            throw JobPilotError.invalid("CSV должен быть в UTF-8.")
        }
        let rows = try CSVCodec.decode(string)
        guard let header = rows.first, header == CSVCodec.headers else {
            throw JobPilotError.invalid("Неизвестные колонки CSV. Используй экспорт из JobPilot.")
        }
        let iso = ISO8601DateFormatter()
        let records: [VacancyRecord] = try rows.dropFirst().enumerated().map { index, c in
            guard c.count == CSVCodec.headers.count, let id = UUID(uuidString: c[0]),
                  let created = iso.date(from: c[13]), let updated = iso.date(from: c[15]) else {
                throw JobPilotError.invalid("Ошибка в CSV, строка \(index + 2).")
            }
            let min = c[4].isEmpty ? nil : Double(c[4])
            let max = c[5].isEmpty ? nil : Double(c[5])
            if (!c[4].isEmpty && min == nil) || (!c[5].isEmpty && max == nil) {
                throw JobPilotError.invalid("Неверная зарплата в CSV, строка \(index + 2).")
            }
            let candidate = Vacancy(id: id, company: c[1], role: c[2], url: c[3].isEmpty ? nil : c[3],
                salaryMin: min, salaryMax: max, currency: c[6].isEmpty ? nil : c[6], location: c[7].isEmpty ? nil : c[7],
                remoteEligibility: c[8], status: c[9], priority: Int(c[10]) ?? 1,
                technologies: c[11].split(separator: ";").map(String.init), source: c[12].isEmpty ? nil : c[12],
                createdAt: created, appliedAt: c[14].isEmpty ? nil : iso.date(from: c[14]), updatedAt: updated, notes: c[16])
            return VacancyRecord(candidate)
        }
        let backup = JobPilotBackup(vacancies: records, stageEvents: [], contacts: [], followUps: [], interviews: [])
        return try importJSON(encoder().encode(backup), into: context)
    }
}
