import SwiftUI
import Charts

/// Дашборд прогресса: серия дней, суммарное время, последние тренировки.
struct ProgressDashboardView: View {
    @EnvironmentObject private var progress: ProgressController
    @EnvironmentObject private var catalog: CatalogController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summary

                    chart

                    perProgram

                    recent
                }
                .padding()
            }
            .navigationTitle("Прогресс")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(title: "Серия", value: "\(progress.currentStreak)", icon: "flame.fill")
            StatTile(title: "Минут", value: "\(Int(progress.totalMinutes.rounded()))", icon: "clock.fill")
            StatTile(title: "Тренировок", value: "\(progress.totalSessions)", icon: "figure.mind.and.body")
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Минут за неделю")
                .font(.headline)
            Chart(progress.minutesByDay(days: 7), id: \.date) { item in
                BarMark(
                    x: .value("День", item.date, unit: .day),
                    y: .value("Минуты", item.minutes)
                )
                .foregroundStyle(.tint)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var perProgram: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("По программам")
                .font(.headline)
            if progress.totalSessions == 0 {
                Text("Пока нет завершённых тренировок.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(catalog.programs.filter { progress.count(forProgram: $0.id) > 0 }) { program in
                    HStack(spacing: 10) {
                        ProgramIcon(name: program.icon, size: 24)
                        Text(program.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(progress.count(forProgram: program.id))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Последние тренировки")
                .font(.headline)

            if progress.records.isEmpty {
                Text("Пока нет завершённых тренировок.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(progress.records.prefix(20)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.programName)
                                .font(.subheadline.weight(.medium))
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(record.duration.rounded())) с")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Локальная аналитика: агрегаты по событиям.
struct AnalyticsView: View {
    @EnvironmentObject private var progress: ProgressController
    @EnvironmentObject private var catalog: CatalogController

    private var summary: AnalyticsSummary { progress.analyticsSummary }

    var body: some View {
        NavigationStack {
            List {
                Section("Сводка") {
                    LabeledContent("Запусков тренировок", value: "\(summary.totalSessions)")
                    LabeledContent("Завершено", value: "\(summary.completedSessions)")
                    LabeledContent("Прервано", value: "\(summary.abortedSessions)")
                    LabeledContent("Доля завершения", value: "\(Int(summary.completionRate * 100))%")
                    LabeledContent("Всего минут", value: "\(Int(summary.totalMinutes.rounded()))")
                    LabeledContent("Средняя тренировка", value: "\(Int(summary.averageSessionMinutes.rounded())) мин")
                    LabeledContent("Разных программ", value: "\(summary.uniquePrograms)")
                }

                Section("Когда вы тренируетесь") {
                    ForEach(["morning", "day", "evening", "night"], id: \.self) { bucket in
                        let count = summary.timeOfDayDistribution[bucket] ?? 0
                        LabeledContent(bucketTitle(bucket), value: "\(count)")
                    }
                }

                if !summary.topPrograms.isEmpty {
                    Section("Популярные программы") {
                        ForEach(summary.topPrograms.prefix(10), id: \.programId) { item in
                            LabeledContent(programTitle(item.programId), value: "\(item.count)")
                        }
                    }
                }

                Section("События") {
                    Text("События собираются только на этом устройстве и никуда не отправляются.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(progress.analyticsEvents.suffix(30).reversed()) { event in
                        HStack {
                            Text(eventTitle(event.kind))
                                .font(.caption)
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Аналитика")
        }
    }

    private func bucketTitle(_ bucket: String) -> String {
        switch bucket {
        case "morning": return "Утро"
        case "day": return "День"
        case "evening": return "Вечер"
        default: return "Ночь"
        }
    }

    private func programTitle(_ id: String) -> String {
        catalogTitle(id)
    }

    private func catalogTitle(_ id: String) -> String {
        catalog.program(id: id)?.name ?? id
    }

    private func eventTitle(_ kind: AnalyticsEvent.Kind) -> String {
        switch kind {
        case .appLaunch: return "Запуск приложения"
        case .programOpen: return "Открыта программа"
        case .sessionStart: return "Начало тренировки"
        case .sessionComplete: return "Тренировка завершена"
        case .sessionAbort: return "Тренировка прервана"
        case .phaseCompleted: return "Фаза завершена"
        case .difficultyChanged: return "Изменена сложность"
        case .achievementUnlocked: return "Получено достижение"
        case .licenseActivated: return "Активирована лицензия"
        case .settingsChanged: return "Изменены настройки"
        case .appShared: return "Приложение отправлено"
        }
    }
}
