import AppIntents

/// Frases de Siri en español. Todas DEBEN incluir \(.applicationName) ("Sturea").
/// Funcionan con Siri en español (Ajustes > Siri > Idioma). Ver GUIA.md.
///
/// TODO(iOS 27): la nueva Siri con IA puede ejecutar los intents por lenguaje natural
/// ("añade un 6,2 en Cálculo") sin frases fijas, usando los parámetros de AddGradeIntent.
/// No uso APIs específicas de iOS 27 porque no puedo verificarlas; con estas frases estándar
/// de iOS 17/18 ya funciona y la nueva Siri las aprovecha.
struct SturShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddGradeIntent(),
            phrases: [
                "Añade una nota en \(.applicationName)",
                "Agrega una nota en \(.applicationName)",
                "Añadir nota en \(.applicationName)",
                "Registra una nota en \(.applicationName)",
                "Anota una nota en \(.applicationName)",
                "Añade una nota de \(\.$course) en \(.applicationName)",
            ],
            shortTitle: "Añadir nota",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: GetGradesSummaryIntent(),
            phrases: [
                "Cómo voy de notas en \(.applicationName)",
                "Cómo voy en \(.applicationName)",
                "Mi promedio en \(.applicationName)",
                "Cuál es mi promedio en \(.applicationName)",
                "Resumen de notas en \(.applicationName)",
                "Mis notas en \(.applicationName)",
            ],
            shortTitle: "Cómo voy de notas",
            systemImageName: "chart.bar.fill"
        )
    }
}
