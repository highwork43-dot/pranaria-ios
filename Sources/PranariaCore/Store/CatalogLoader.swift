import Foundation

/// Загрузчик каталога программ и достижений.
///
/// Каталог лежит в JSON (Content/programs.json, Content/achievements.json) и
/// генерируется скриптами Tools/extract_*.py из декомпилированного кода
/// оригинального приложения. Путь передаётся снаружи — так ядро не зависит
/// ни от Bundle, ни от файловой системы конкретной платформы.
public enum CatalogLoader {

    public enum LoadError: Error, LocalizedError {
        case fileNotFound(String)
        case decodingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let name): return "Файл \(name) не найден"
            case .decodingFailed(let detail): return "Не удалось разобрать каталог: \(detail)"
            }
        }
    }

    // MARK: - Программы

    public static func loadPrograms(from url: URL) throws -> [Program] {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([Program].self, from: data)
        } catch {
            throw LoadError.decodingFailed(String(describing: error))
        }
    }

    // MARK: - Достижения

    public static func loadAchievements(from url: URL) throws -> [Achievement] {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([Achievement].self, from: data)
        } catch {
            throw LoadError.decodingFailed(String(describing: error))
        }
    }

    // MARK: - Поиск файлов рядом с приложением

    /// Ищет ресурс в бандле, затем рядом с исходниками (для тестов и CLI).
    public static func locate(
        resource: String,
        extension ext: String,
        subdirectory: String? = nil,
        searchPaths: [String] = []
    ) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: ext) {
            return url
        }
        if let subdirectory,
           let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path)
                .appendingPathComponent("Content")
                .appendingPathComponent(resource)
                .appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
