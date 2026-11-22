import SwiftUI

/// Достижения: 33 штуки, как в оригинале.
struct AchievementsView: View {
    @EnvironmentObject private var catalog: CatalogController
    @EnvironmentObject private var progress: ProgressController

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        StatTile(title: "Получено", value: "\(progress.unlockedAchievementIDs.count)", icon: "trophy.fill")
                        StatTile(title: "Всего", value: "\(catalog.achievements.count)", icon: "trophy")
                        StatTile(title: "Тренировок", value: "\(progress.totalSessions)", icon: "figure.mind.and.body")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(catalog.achievements) { achievement in
                    AchievementRow(
                        achievement: achievement,
                        unlocked: progress.unlockedAchievementIDs.contains(achievement.id)
                    )
                }
            }
            .navigationTitle("Достижения")
            .overlay {
                if catalog.achievements.isEmpty {
                    ContentUnavailableView(
                        "Достижения не загружены",
                        systemImage: "trophy",
                        description: Text("Проверьте наличие файла Content/achievements.json в бандле.")
                    )
                }
            }
            .onAppear {
                progress.refreshAchievements(catalog: catalog.achievements)
            }
        }
    }
}

/// Строка достижения.
struct AchievementRow: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(unlocked ? Color.yellow.opacity(0.18) : Color.gray.opacity(0.15))
                    .frame(width: 52, height: 52)
                if unlocked {
                    ProgramIcon(name: achievement.icon, size: 34)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(unlocked ? .primary : .secondary)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Плитка показателя.
struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Общие инструкции по практике.
struct InstructionsView: View {
    var body: some View {
        List {
            Section("Как заниматься") {
                ForEach(InstructionProvider.generalInstructions, id: \.self) { line in
                    Label {
                        Text(line)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.tint)
                    }
                }
            }

            Section("Способы дыхания") {
                ForEach(1...4, id: \.self) { way in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(InstructionProvider.breathingWayDescription(way))
                            .font(.callout)
                    }
                }
            }

            Section("Голосовое сопровождение") {
                Text("В настройках можно включить голосовые подсказки: приложение будет называть фазы («Вдох», «Выдох», «Задержка») и объявлять номер цикла. Отдельный режим подробных инструкций проговаривает, как выполнять каждую фазу.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Если чувствуете дискомфорт") {
                Text("Головокружение, боль в груди, паника — сигнал прекратить практику. Вернитесь к обычному дыханию и вернитесь позже. Практика не должна быть усилием: если приходится задерживать дыхание «через силу», уменьшите длительность фазы или смените программу.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Инструкции")
        .navigationBarTitleDisplayMode(.inline)
    }
}
