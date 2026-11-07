import Foundation

enum JobPilotError: LocalizedError {
    case invalid(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message), .unsupported(let message): return message
        }
    }
}

enum ValidationService {
    static func normalizedURL(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(), host.contains("."),
              !host.contains(" ") else { return nil }
        components.scheme = "https"
        components.host = host
        components.fragment = nil
        let tracking = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid", "gclid"]
        components.queryItems = components.queryItems?.filter { !tracking.contains($0.name.lowercased()) }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        let path = components.percentEncodedPath
        if path == "/" { components.percentEncodedPath = "" }
        else if path.count > 1 && path.hasSuffix("/") { components.percentEncodedPath = String(path.dropLast()) }
        return components.url?.absoluteString
    }

    static func numericSalary(_ raw: String, label: String) throws -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount >= 0, amount.isFinite else {
            throw JobPilotError.invalid("Поле «\(label)»: укажи неотрицательное число.")
        }
        return amount
    }

    static func validated(_ draft: VacancyDraft) throws -> ValidVacancy {
        let company = draft.company.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = draft.role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.isEmpty else { throw JobPilotError.invalid("Укажи компанию.") }
        guard !role.isEmpty else { throw JobPilotError.invalid("Укажи должность.") }
        let rawURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = normalizedURL(rawURL)
        if !rawURL.isEmpty && url == nil {
            throw JobPilotError.invalid("Ссылка должна вести на http или https сайт.")
        }
        let min = try numericSalary(draft.salaryMin, label: "Зарплата от")
        let max = try numericSalary(draft.salaryMax, label: "Зарплата до")
        if let min, let max, min > max {
            throw JobPilotError.invalid("Минимальная зарплата больше максимальной.")
        }
        return ValidVacancy(company: company, role: role, url: url, salaryMin: min, salaryMax: max,
            currency: draft.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            location: draft.location.trimmingCharacters(in: .whitespacesAndNewlines),
            remote: draft.remote, priority: draft.priority, technologies: draft.parsedTechnologies,
            source: draft.source.trimmingCharacters(in: .whitespacesAndNewlines), notes: draft.notes)
    }
}

struct ValidVacancy {
    let company: String
    let role: String
    let url: String?
    let salaryMin: Double?
    let salaryMax: Double?
    let currency: String
    let location: String
    let remote: RemoteEligibility
    let priority: VacancyPriority
    let technologies: [String]
    let source: String
    let notes: String
}

struct VacancyFilter: Equatable {
    var status: VacancyStatus? = nil
    var search = ""
    var role = ""
    var technology = ""
    var priority: VacancyPriority? = nil
    var eligibility: RemoteEligibility? = nil

    func matches(_ vacancy: Vacancy) -> Bool {
        if let status, vacancy.status != status.rawValue { return false }
        if let priority, vacancy.priority != priority.rawValue { return false }
        if let eligibility, vacancy.remoteEligibility != eligibility.rawValue { return false }
        if !role.isEmpty && !vacancy.role.localizedStandardContains(role) { return false }
        if !technology.isEmpty && !vacancy.technologies.contains(where: { $0.localizedStandardContains(technology) }) { return false }
        if !search.isEmpty {
            let haystack = [vacancy.company, vacancy.role, vacancy.notes, vacancy.location ?? "", vacancy.technologies.joined(separator: " ")].joined(separator: " ")
            if !haystack.localizedStandardContains(search) { return false }
        }
        return true
    }
}

enum StatusRules {
    static func shouldRecord(old: VacancyStatus, new: VacancyStatus) -> Bool { old != new }
    static func appliedDate(current: Date?, new: VacancyStatus, now: Date) -> Date? {
        current ?? (new == .applied ? now : nil)
    }
}
