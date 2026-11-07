import Foundation

struct VacancyDraft {
    var company = ""
    var role = ""
    var url = ""
    var salaryMin = ""
    var salaryMax = ""
    var currency = "USD"
    var location = ""
    var remote: RemoteEligibility = .unknown
    var priority: VacancyPriority = .normal
    var technologies = ""
    var source = ""
    var notes = ""

    init() {}
    init(_ vacancy: Vacancy) {
        company = vacancy.company; role = vacancy.role; url = vacancy.url ?? ""
        salaryMin = vacancy.salaryMin.map { String($0) } ?? ""
        salaryMax = vacancy.salaryMax.map { String($0) } ?? ""
        currency = vacancy.currency ?? "USD"; location = vacancy.location ?? ""
        remote = vacancy.eligibility; priority = vacancy.vacancyPriority
        technologies = vacancy.technologies.joined(separator: ", ")
        source = vacancy.source ?? ""; notes = vacancy.notes
    }
    var parsedTechnologies: [String] {
        var seen = Set<String>()
        return technologies.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
