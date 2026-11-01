import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

// MARK: - Entidad

/// Un ramo de Sturea. Siri la usa para resolver "Cálculo", "física 2", etc.
struct CourseEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ramo"
    static let defaultQuery = CourseQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Query (búsqueda difusa)

struct CourseQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CourseEntity] {
        let all = await CourseCatalog.courses()
        return all.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [CourseEntity] {
        let all = await CourseCatalog.courses()
        return CourseCatalog.fuzzyMatch(string, in: all)
    }

    func suggestedEntities() async throws -> [CourseEntity] {
        await CourseCatalog.courses()
    }
}

// MARK: - Catálogo (API + caché local para funcionar sin conexión al sugerir)

enum CourseCatalog {
    private static let cacheKey = "sturea.coursesCache"

    private struct Cached: Codable { let id: String; let name: String }

    /// Intenta la API; si falla (sin red, sin token) usa la última lista guardada.
    static func courses() async -> [CourseEntity] {
        if let fresh = try? await APIClient.shared.courses() {
            save(fresh)
            return fresh.map { CourseEntity(id: $0.id, name: $0.name) }
        }
        return cached()
    }

    static func refreshAndIndex() async {
        let list = await courses()
        guard !list.isEmpty else { return }
        await index(list)
        // Avisa a Siri de los ramos disponibles para las frases con parámetro.
        SturShortcuts.updateAppShortcutParameters()
    }

    private static func save(_ list: [CourseDTO]) {
        let items = list.map { Cached(id: $0.id, name: $0.name) }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private static func cached() -> [CourseEntity] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let items = try? JSONDecoder().decode([Cached].self, from: data) else { return [] }
        return items.map { CourseEntity(id: $0.id, name: $0.name) }
    }

    // MARK: Spotlight

    /// Indexa los ramos en Spotlight (búsqueda del sistema).
    /// TODO(iOS 18+/27): adoptar `IndexedEntity` en CourseEntity y usar `appEntityIdentifier`
    /// para que Siri / contexto personal enlacen estos items con la entidad. No lo uso aquí
    /// porque no puedo verificar la API exacta sin compilar en un Mac.
    private static func index(_ list: [CourseEntity]) async {
        let items = list.map { course -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            attrs.title = course.name
            attrs.contentDescription = "Ramo en Sturea"
            attrs.keywords = ["Sturea", "notas", "ramo", course.name]
            return CSSearchableItem(
                uniqueIdentifier: "sturea.course.\(course.id)",
                domainIdentifier: "com.draxxd.sturea.courses",
                attributeSet: attrs
            )
        }
        let index = CSSearchableIndex.default()
        try? await index.deleteSearchableItems(withDomainIdentifiers: ["com.draxxd.sturea.courses"])
        try? await index.indexSearchableItems(items)
    }

    // MARK: Coincidencia difusa

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        let ca = Array(a), cb = Array(b)
        let maxLen = max(ca.count, cb.count)
        return maxLen == 0 ? 0 : 1 - Double(levenshtein(ca, cb)) / Double(maxLen)
    }

    static func score(query: String, name: String) -> Double {
        let q = normalize(query), n = normalize(name)
        if q.isEmpty || n.isEmpty { return 0 }
        if q == n { return 1 }
        if n.contains(q) || q.contains(n) { return 0.9 }
        var best = similarity(q, n)
        for word in n.split(separator: " ") {
            best = max(best, similarity(q, String(word)))
        }
        return best
    }

    static func fuzzyMatch(_ query: String, in list: [CourseEntity]) -> [CourseEntity] {
        list
            .map { ($0, score(query: query, name: $0.name)) }
            .filter { $0.1 >= 0.6 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}
