import SwiftUI

/// Ajustes mínimos: pegar el token personal (Keychain) y, si hace falta, la URL de la API.
struct SettingsView: View {
    var onReload: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var apiURL = UserDefaults.standard.string(forKey: APIConfig.baseURLDefaultsKey) ?? ""
    @State private var hasToken = KeychainStore.loadToken() != nil
    @State private var status = ""
    @State private var statusIsError = false
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(hasToken ? "Token guardado (pega uno nuevo para reemplazar)" : "Pega tu token personal", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Guardar token") { saveToken() }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasToken {
                        Button("Borrar token", role: .destructive) {
                            KeychainStore.deleteToken()
                            hasToken = false
                            show("Token borrado.", error: false)
                        }
                    }
                } header: {
                    Text("Token de API")
                } footer: {
                    Text("Se guarda solo en el Keychain de este iPhone. Siri lo usa para añadir y consultar notas.")
                }

                Section {
                    TextField("https://xxxx.supabase.co/functions/v1/grades-api", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Guardar URL") {
                        UserDefaults.standard.set(apiURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                                  forKey: APIConfig.baseURLDefaultsKey)
                        show("URL guardada.", error: false)
                    }
                } header: {
                    Text("URL de la API")
                } footer: {
                    Text("Solo si no la dejaste ya configurada en el build.")
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Text("Probar conexión")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing)

                    if !status.isEmpty {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(statusIsError ? .red : .green)
                    }
                }

                Section {
                    Button("Recargar Sturea") {
                        onReload()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func show(_ text: String, error: Bool) {
        status = text
        statusIsError = error
    }

    private func saveToken() {
        if KeychainStore.saveToken(token) {
            token = ""
            hasToken = true
            show("Token guardado.", error: false)
        } else {
            show("No pude guardar el token en el Keychain.", error: true)
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let summary = try await APIClient.shared.summary()
            await CourseCatalog.refreshAndIndex()
            show("Conexión correcta: \(summary.subjects.count) ramos encontrados.", error: false)
        } catch let e as APIError {
            show(e.spokenMessage, error: true)
        } catch {
            show("Error desconocido.", error: true)
        }
    }
}
