import SwiftUI

@main
struct PranariaApp: App {
    @StateObject private var catalog = CatalogController()
    @StateObject private var progress = ProgressController(
        fileURL: AppPaths.progressFile,
        analyticsURL: AppPaths.analyticsFile,
        achievementsURL: AppPaths.achievementsFile
    )
    @StateObject private var license = LicenseController(licenseURL: AppPaths.licenseFile)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(catalog)
                .environmentObject(progress)
                .environmentObject(license)
                .tint(Color(hex: "#9F82D9"))
                .task {
                    catalog.load()
                    license.validateEmbeddedLicense()
                    progress.refreshAchievements(catalog: catalog.achievements)
                }
        }
    }
}

/// Пути к данным приложения.
enum AppPaths {

    /// Корень пакета (рядом с Content/) — для запуска из исходников и тестов.
    nonisolated static var packageRoot: String {
        URL(fileURLWithPath: #filePath)   // Sources/PranariaApp/App/AppState.swift
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // PranariaApp
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // корень пакета
            .path
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Pranaria", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var progressFile: URL { directory.appendingPathComponent("progress.json") }
    static var analyticsFile: URL { directory.appendingPathComponent("analytics.json") }
    static var achievementsFile: URL { directory.appendingPathComponent("achievements-state.json") }

    /// Лицензия лежит в бандле (Content/license.json), но при установке из
    /// исходников может находиться рядом с пакетом.
    static var licenseFile: URL? {
        if let url = Bundle.main.url(forResource: "license", withExtension: "json") {
            return url
        }
        if let url = Bundle.main.url(
            forResource: "license", withExtension: "json", subdirectory: "Content"
        ) {
            return url
        }
        let candidate = URL(fileURLWithPath: CatalogController.packageRoot)
            .appendingPathComponent("Content/license.json")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

/// Корневые вкладки приложения.
struct RootView: View {
    @EnvironmentObject private var catalog: CatalogController
    @EnvironmentObject private var progress: ProgressController
    @EnvironmentObject private var license: LicenseController

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem { Label("Тренировки", systemImage: "wind") }
                .tag(0)

            AchievementsView()
                .tabItem { Label("Достижения", systemImage: "trophy") }
                .tag(1)

            ProgressDashboardView()
                .tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }
                .tag(2)

            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "waveform.path.ecg") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(4)
        }
        .overlay(alignment: .top) {
            if let achievement = progress.recentAchievement {
                AchievementBanner(achievement: achievement) {
                    withAnimation { progress.recentAchievement = nil }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring, value: progress.recentAchievement)
    }
}

/// Баннер о новом достижении.
struct AchievementBanner: View {
    let achievement: Achievement
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProgramIcon(name: achievement.icon, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Достижение получено")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(achievement.name)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .shadow(radius: 8, y: 4)
    }
}
