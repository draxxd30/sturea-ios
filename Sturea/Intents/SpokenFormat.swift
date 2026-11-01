import AppIntents
import Foundation

/// Error que Siri lee en voz alta tal cual.
struct SpokenError: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    var localizedStringResource: LocalizedStringResource { "\(message)" }

    init(_ api: APIError) { self.message = api.spokenMessage }
    init(message: String) { self.message = message }
}

/// Convierte la respuesta de la API en frases cortas en español (coma decimal).
enum Spoken {
    static func number(_ value: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func neededPhrase(_ s: SubjectSummary, settings: APISettings) -> String {
        switch s.needed.status {
        case "needed":
            if let g = s.needed.grade {
                return "necesitas un \(number(g, decimals: settings.decimals)) en lo que queda para aprobar"
            }
            return "aún te faltan evaluaciones"
        case "already":
            return "ya tienes asegurado aprobar"
        case "impossible":
            return "ya no alcanzas a aprobar"
        case "none_left":
            return s.passing == true ? "ya aprobaste" : "ya no te quedan evaluaciones y quedaste bajo la nota de aprobación"
        default:
            return "todavía no tiene notas"
        }
    }

    static func courseSummary(_ s: SubjectSummary, settings: APISettings) -> String {
        guard let avg = s.average else { return "En \(s.name) todavía no tienes notas." }
        return "En \(s.name) tu promedio es \(number(avg, decimals: settings.decimals)); \(neededPhrase(s, settings: settings))."
    }

    static func fullSummary(_ r: SummaryResponse) -> String {
        guard !r.subjects.isEmpty else { return "Todavía no tienes ramos en Sturea." }
        var parts: [String] = []
        if let g = r.general.average {
            parts.append("Tu promedio general es \(number(g, decimals: r.settings.decimals)).")
        } else {
            parts.append("Todavía no tienes notas registradas.")
        }
        // Detalle breve: máximo 5 ramos con nota, para que Siri no se alargue.
        let withAvg = r.subjects.filter { $0.average != nil }
        for s in withAvg.prefix(5) {
            parts.append("\(s.name), \(number(s.average!, decimals: r.settings.decimals)).")
        }
        // Alertas: ramos donde aún hay que sacar cierta nota o no se alcanza.
        for s in withAvg where s.needed.status == "needed" || s.needed.status == "impossible" {
            parts.append("En \(s.name) \(neededPhrase(s, settings: r.settings)).")
            if parts.count > 9 { break }
        }
        return parts.joined(separator: " ")
    }
}
