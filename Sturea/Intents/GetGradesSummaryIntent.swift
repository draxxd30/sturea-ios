import AppIntents

/// "¿Cómo voy de notas?" / "¿Cuál es mi promedio de Física?" → GET /summary
struct GetGradesSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver cómo voy de notas"
    static let description = IntentDescription("Te dice tus promedios y la nota que necesitas para aprobar.")
    static let openAppWhenRun = false

    @Parameter(title: "Ramo", description: "Opcional. Si lo omites, resumo todos tus ramos.")
    var course: CourseEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Ver notas de \(\.$course)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let res = try await APIClient.shared.summary(course: course?.name)
            let text: String
            if course != nil, let s = res.subjects.first {
                text = Spoken.courseSummary(s, settings: res.settings)
            } else {
                text = Spoken.fullSummary(res)
            }
            return .result(dialog: "\(text)")
        } catch let e as APIError {
            throw SpokenError(e)
        } catch {
            throw SpokenError(message: "No pude consultar tus notas. Inténtalo de nuevo.")
        }
    }
}
