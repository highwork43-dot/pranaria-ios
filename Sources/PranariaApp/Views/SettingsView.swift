import SwiftUI
import UniformTypeIdentifiers

/// Настройки: звук, голос, лицензия, резервная копия, инструкции.
struct SettingsView: View {
    @EnvironmentObject private var license: LicenseController
    @EnvironmentObject private var progress: ProgressController

    @AppStorage("session.background") private var backgroundSound = "bg_01"
    @AppStorage("session.metronome") private var metronomeSound = "metro_01"
    @AppStorage("session.metronomeOn") private var metronomeOn = false
    @AppStorage("session.haptics") private var hapticsEnabled = true
    @AppStorage("session.backgroundVolume") private var backgroundVolume = 0.6
    @AppStorage("session.voice") private var voiceEnabled = false
    @AppStorage("session.voiceGuidance") private var voiceGuidance = false

    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var isActivating = false
    @State private var showInstructions = false

    var body: some View {
        NavigationStack {
            Form {
                licenseSection
                voiceSection
                soundSection
                dataSection
                aboutSection
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showInstructions) {
                NavigationStack { InstructionsView() }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: JSONDocument(data: progress.exportData() ?? Data()),
                contentType: .json,
                defaultFilename: "pranaria-progress"
            ) { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let data = try Data(contentsOf: url)
                        try progress.importData(data)
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Ошибка импорта", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("ОК", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    // MARK: - License

    private var licenseSection: some View {
        Section {
            if license.isFullVersion {
                Label("Полная версия активна", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)

                if let info = license.license {
                    LabeledContent("Владелец", value: info.holder)
                    LabeledContent("Почта", value: info.email)
                    LabeledContent("Уровень", value: info.level)
                    if let purchase = info.purchase {
                        LabeledContent("Покупка", value: "\(purchase.date) · \(Int(purchase.amount)) \(purchase.currency)")
                        LabeledContent("Чек №", value: purchase.receipt)
                        LabeledContent("Продавец", value: purchase.seller)
                    }
                }
            } else {
                TextField("Промокод", text: $license.promoCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task {
                        isActivating = true
                        await license.activate(promoCode: license.promoCode)
                        isActivating = false
                    }
                } label: {
                    if isActivating { ProgressView() } else { Text("Активировать промокод") }
                }
                .disabled(isActivating || license.promoCode.isEmpty)

                Button("Восстановить покупки") {
                    Task {
                        isActivating = true
                        await license.restorePurchase()
                        isActivating = false
                    }
                }
                .disabled(isActivating)
            }

            Text("Как продолжить использовать полную версию на новом устройстве?")
                .font(.footnote)
                .foregroundStyle(.secondary)

            DisclosureGroup("Настройка сервера лицензий") {
                TextField("Адрес endpoint", text: $license.licenseEndpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
                TextField("Идентификатор покупателя", text: $license.purchaserId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
                Text("Эндпоинт выдаёт разработчик mEL Studio: он проверяет промокод или покупку и отвечает {\"active\": true}.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Сохранить") { license.persistSettings() }
            }
            .font(.footnote)
        } header: {
            Text("Полная версия")
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        Section("Голосовые инструкции") {
            Toggle("Озвучивать фазы", isOn: $voiceEnabled)
            Toggle("Подробные инструкции", isOn: $voiceGuidance)
                .disabled(!voiceEnabled)
            Button("Инструкция по практике") { showInstructions = true }
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section("Звук") {
            Picker("Фоновая музыка", selection: $backgroundSound) {
                ForEach(AudioDirector.availableBackgrounds, id: \.self) { name in
                    Text(name.replacingOccurrences(of: "_", with: " ")).tag(name)
                }
            }
            Slider(value: $backgroundVolume, in: 0...1) {
                Text("Громкость фона")
            }
            Toggle("Метроном", isOn: $metronomeOn)
            if metronomeOn {
                Picker("Метроном", selection: $metronomeSound) {
                    ForEach(AudioDirector.availableMetronomes, id: \.self) { name in
                        Text(name.replacingOccurrences(of: "_", with: " ")).tag(name)
                    }
                }
            }
            Toggle("Тактильная отдача", isOn: $hapticsEnabled)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Данные") {
            Button("Экспорт прогресса") { showExporter = true }
            Button("Импорт прогресса") { showImporter = true }
            Button("Удалить все данные", role: .destructive) {
                progress.removeAll()
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("О приложении") {
            Text("Пранария — дыхательные практики")
            Text("iOS-порт, собранный из ресурсов оригинального приложения mEL Studio для личного использования.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Программ", value: "24")
            LabeledContent("Достижений", value: "33")
            Link("Условия использования оригинала", destination: URL(string: "https://melstudio.info/en/terms-pranaria")!)
            Link("Политика конфиденциальности оригинала", destination: URL(string: "https://melstudio.info/en/privacy-policy-pranaria")!)
        }
    }
}

/// Обёртка для экспорта прогресса в JSON.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
