import Foundation

// MARK: - Modelos (reflejan la respuesta de la Edge Function grades-api)

struct APISettings: Decodable {
    let scaleMin: Double
    let scaleMax: Double
    let passGrade: Double
    let decimals: Int
}

struct NeededInfo: Decodable {
    let status: String   // none_left | already | needed | impossible | no_data
    let grade: Double?
}

struct SubjectSummary: Decodable {
    let id: String
    let name: String
    let average: Double?
    let gradedCount: Int
    let pendingCount: Int
    let passing: Bool?
    let needed: NeededInfo
}

struct GeneralSummary: Decodable {
    let average: Double?
    let passing: Bool?
}

struct SummaryResponse: Decodable {
    let settings: APISettings
    let subjects: [SubjectSummary]
    let general: GeneralSummary
}

struct AddGradeResponse: Decodable {
    let course: SubjectSummary
    let general: GeneralSummary
    let settings: APISettings
}

struct CourseDTO: Decodable {
    let id: String
    let name: String
}

private struct CoursesResponse: Decodable { let courses: [CourseDTO] }

private struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
        let courses: [String]?
    }
    let error: Body
}

// MARK: - Errores (mensajes pensados para que Siri los lea en voz alta)

enum APIError: Error, LocalizedError {
    case noToken
    case noBaseURL
    case invalidToken
    case offline
    case courseNotFound(String, [String])
    case courseAmbiguous(String)
    case gradeOutOfRange(String)
    case noData
    case server(String)

    var errorDescription: String? { spokenMessage }

    var spokenMessage: String {
        switch self {
        case .noToken:
            return "Todavía no configuraste tu token. Ábrelo en Ajustes dentro de la app Sturea."
        case .noBaseURL:
            return "Falta la dirección de la API. Configúrala en Ajustes dentro de la app Sturea."
        case .invalidToken:
            return "Tu token no es válido o fue revocado. Pega uno nuevo en Ajustes de la app Sturea."
        case .offline:
            return "No tengo conexión a internet. Inténtalo de nuevo en un momento."
        case .courseNotFound(let q, let names):
            let list = names.prefix(6).joined(separator: ", ")
            return names.isEmpty
                ? "No encontré el ramo \(q)."
                : "No encontré el ramo \(q). Tus ramos son: \(list)."
        case .courseAmbiguous(let q):
            return "Hay varios ramos parecidos a \(q). Dime el nombre completo."
        case .gradeOutOfRange(let msg):
            return msg
        case .noData:
            return "Todavía no tienes notas guardadas en Sturea."
        case .server(let msg):
            return msg.isEmpty ? "Sturea tuvo un problema. Inténtalo más tarde." : msg
        }
    }
}

// MARK: - Cliente

enum APIConfig {
    static let baseURLDefaultsKey = "sturea.apiBaseURL"

    /// Prioridad: valor puesto en Ajustes > valor de Info.plist (project.yml).
    static var baseURL: URL? {
        let custom = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let plist = Bundle.main.object(forInfoDictionaryKey: "SturApiBaseURL") as? String
        for candidate in [custom, plist] {
            guard var s = candidate, !s.isEmpty, !s.contains("TU-PROYECTO") else { continue }
            while s.hasSuffix("/") { s.removeLast() }
            if let url = URL(string: s), url.scheme == "https" { return url }
        }
        return nil
    }
}

struct APIClient {
    static let shared = APIClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    // MARK: Endpoints

    func courses() async throws -> [CourseDTO] {
        let data = try await request(path: "/courses")
        return try decode(CoursesResponse.self, data).courses
    }

    func summary(course: String? = nil) async throws -> SummaryResponse {
        var query: [URLQueryItem] = []
        if let course, !course.isEmpty { query.append(URLQueryItem(name: "course", value: course)) }
        let data = try await request(path: "/summary", query: query)
        return try decode(SummaryResponse.self, data)
    }

    func addGrade(course: String, grade: Double, weight: Double? = nil, date: Date = Date()) async throws -> AddGradeResponse {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        var body: [String: Any] = ["course": course, "grade": grade, "date": df.string(from: date)]
        if let weight { body["weight"] = weight }
        let data = try await request(path: "/grades", method: "POST", body: body)
        return try decode(AddGradeResponse.self, data)
    }

    // MARK: Núcleo

    private func request(path: String, query: [URLQueryItem] = [], method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let token = KeychainStore.loadToken() else { throw APIError.noToken }
        guard let base = APIConfig.baseURL else { throw APIError.noBaseURL }

        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                throw APIError.offline
            default:
                throw APIError.server("")
            }
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.server("") }
        if (200..<300).contains(http.statusCode) { return data }

        if http.statusCode == 401 { throw APIError.invalidToken }
        let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        let message = env?.error.message ?? ""
        switch env?.error.code {
        case "course_not_found": throw APIError.courseNotFound(extractCourse(message), env?.error.courses ?? [])
        case "course_ambiguous": throw APIError.courseAmbiguous(extractCourse(message))
        case "grade_out_of_range", "invalid_grade", "invalid_weight": throw APIError.gradeOutOfRange(message)
        case "no_data": throw APIError.noData
        default: throw APIError.server(message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.server("Recibí una respuesta que no entendí.") }
    }

    private func extractCourse(_ message: String) -> String {
        // El mensaje del servidor trae el nombre entre comillas: ... "Cálculo" ...
        let parts = message.split(separator: "\"")
        return parts.count >= 2 ? String(parts[1]) : "ese"
    }
}
