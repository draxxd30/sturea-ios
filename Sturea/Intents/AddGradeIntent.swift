import AppIntents

/// "Añade un 6,2 en Cálculo" → POST /grades
struct AddGradeIntent: AppIntent {
    static let title: LocalizedStringResource = "Añadir nota"
    static let description = IntentDescription("Añade una nota a un ramo en Sturea.")
    static let openAppWhenRun = false

    @Parameter(title: "Ramo", requestValueDialog: "¿En qué ramo?")
    var course: CourseEntity

    @Parameter(title: "Nota", requestValueDialog: "¿Qué nota?")
    var grade: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Añadir un \(\.$grade) en \(\.$course)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let res = try await APIClient.shared.addGrade(course: course.name, grade: grade)
            let d = res.settings.decimals
            let gradeText = Spoken.number(grade, decimals: d)
            var text = "Listo, añadí un \(gradeText) en \(res.course.name)."
            if let avg = res.course.average {
                text += " Tu promedio ahora es \(Spoken.number(avg, decimals: d))."
            }
            if let general = res.general.average {
                text += " Tu promedio general es \(Spoken.number(general, decimals: d))."
            }
            return .result(dialog: "\(text)")
        } catch let e as APIError {
            throw SpokenError(e)
        } catch {
            throw SpokenError(message: "No pude guardar la nota. Inténtalo de nuevo.")
        }
    }
}
