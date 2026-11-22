import SwiftUI

/// Библиотека программ: список по категориям, как в оригинале.
struct LibraryView: View {
    @EnvironmentObject private var catalog: CatalogController
    @EnvironmentObject private var license: LicenseController

    var body: some View {
        NavigationStack {
            List {
                if let error = catalog.loadError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(catalog.categoryTitles, id: \.self) { category in
                    let programs = catalog.programs(inCategoryTitle: category)
                    if !programs.isEmpty {
                        Section {
                            ForEach(programs) { program in
                                NavigationLink {
                                    ProgramDetailView(program: program)
                                } label: {
                                    ProgramRow(program: program, isLocked: isLocked(program))
                                }
                            }
                        } header: {
                            Text(category)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Тренировки")
            .overlay {
                if catalog.programs.isEmpty {
                    ContentUnavailableView(
                        "Каталог не загружен",
                        systemImage: "wind",
                        description: Text("Проверьте наличие файла Content/programs.json в бандле приложения.")
                    )
                }
            }
        }
    }

    private func isLocked(_ program: Program) -> Bool {
        program.isMeditation && !license.isFullVersion
    }
}

/// Строка программы в списке.
struct ProgramRow: View {
    let program: Program
    var isLocked: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: program.backgroundColor).opacity(0.25))
                    .frame(width: 52, height: 52)
                ProgramIcon(name: program.icon, size: 34)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(program.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !program.shortDescription.isEmpty {
                    Text(program.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Экран программы: описание, сложность, инструкция, запуск.
struct ProgramDetailView: View {
    let program: Program

    @EnvironmentObject private var catalog: CatalogController
    @EnvironmentObject private var license: LicenseController
    @EnvironmentObject private var progress: ProgressController

    @State private var difficulty: Double = 0
    @State private var showSession = false

    private var plan: ProgramPlan {
        ProgramPlan.make(program: program, difficulty: Int(difficulty))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !program.shortDescription.isEmpty {
                    Text(program.shortDescription)
                        .font(.headline)
                }

                details

                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                instructionCard
                difficultyPicker

                Button {
                    showSession = true
                } label: {
                    Label("Начать", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(program.isMeditation && !license.isFullVersion)
            }
            .padding()
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showSession) {
            SessionView(plan: plan)
        }
        .onAppear {
            difficulty = Double(program.difficulty)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: program.backgroundColor).opacity(0.25))
                    .frame(width: 84, height: 84)
                ProgramIcon(name: program.icon, size: 56)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.proportionsDescription)
                    .font(.title2.weight(.semibold))
                Text("Циклов: \(plan.cycleCount) · \(formatDuration(plan.totalDuration))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Выполнено: \(progress.count(forProgram: program.id))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Категория", program.categoryTitle)
            row("Длительность", "\(program.lengthMinutes) мин")
            row("Сложность", "\(Int(difficulty) + 1) из \(program.maxDifficulty + 1)")
            if !program.categoryDescription.isEmpty {
                Text(program.categoryDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Инструкция", systemImage: "info.circle")
                .font(.headline)
            Text(InstructionProvider.techniqueBriefing(for: plan))
                .font(.callout)
                .foregroundStyle(.secondary)
            let ways = Set(program.breatheWay.filter { $0 > 0 })
            if !ways.isEmpty {
                ForEach(ways.sorted(), id: \.self) { way in
                    Text("• " + InstructionProvider.breathingWayDescription(way))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var difficultyPicker: some View {
        if program.maxDifficulty > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Уровень сложности")
                    Spacer()
                    Text("\(Int(difficulty) + 1)")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $difficulty, in: 0...Double(program.maxDifficulty), step: 1)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let rest = total % 60
        return minutes > 0 ? "\(minutes) мин \(rest) с" : "\(rest) с"
    }
}
