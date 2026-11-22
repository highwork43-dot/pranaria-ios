import Foundation

/// Лицензия на полную версию.
///
/// Формат повторяет идею оригинала (уровень доступа, привязанный к
/// покупателю), но проверка целостности делается локально: лицензия — это
/// JSON с подписью HMAC-SHA256. Это проверка целостности, а не DRM:
/// ключ лежит внутри приложения и может быть извлечён злоумышленником.
public struct License: Codable, Hashable {

    /// Сведения о покупке, подтверждающие право на полную версию.
    public struct Purchase: Codable, Hashable {
        public var date: String
        public var amount: Double
        public var currency: String
        public var receipt: String
        public var seller: String
        public var fiscalDocument: String
        public var documentNumber: String
        public var sign: String

        public init(
            date: String,
            amount: Double,
            currency: String = "RUB",
            receipt: String,
            seller: String,
            fiscalDocument: String,
            documentNumber: String,
            sign: String
        ) {
            self.date = date
            self.amount = amount
            self.currency = currency
            self.receipt = receipt
            self.seller = seller
            self.fiscalDocument = fiscalDocument
            self.documentNumber = documentNumber
            self.sign = sign
        }
    }

    public var licenseId: String
    public var holder: String
    public var email: String
    /// pro | free
    public var level: String
    public var issuedAt: String
    public var expiresAt: String?
    public var purchase: Purchase?

    public init(
        licenseId: String,
        holder: String,
        email: String,
        level: String,
        issuedAt: String,
        expiresAt: String? = nil,
        purchase: Purchase? = nil
    ) {
        self.licenseId = licenseId
        self.holder = holder
        self.email = email
        self.level = level
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.purchase = purchase
    }

    public var isPro: Bool { level == "pro" }
}

/// Файл лицензии: полезная нагрузка + подпись.
public struct LicenseEnvelope: Codable, Hashable {
    public var version: Int
    public var payload: License
    public var signature: String

    public init(version: Int, payload: License, signature: String) {
        self.version = version
        self.payload = payload
        self.signature = signature
    }
}

/// Менеджер лицензий: проверяет подпись, срок действия и уровень доступа.
public final class LicenseManager {

    /// Ключ подписи. Встроен в приложение — это проверка целостности,
    /// а не защита от копирования (см. docs/RE-NOTES.md).
    public static let signingKey = "pranaria.personal.2026.11.owner.license.key"

    public enum LicenseError: Error, LocalizedError {
        case fileNotFound
        case invalidSignature
        case expired
        case notPro

        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Файл лицензии не найден"
            case .invalidSignature: return "Подпись лицензии недействительна"
            case .expired: return "Срок действия лицензии истёк"
            case .notPro: return "Уровень доступа не соответствует полной версии"
            }
        }
    }

    private let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    // MARK: - Загрузка и проверка

    public func loadEnvelope() throws -> LicenseEnvelope {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            throw LicenseError.fileNotFound
        }
        return try JSONDecoder().decode(LicenseEnvelope.self, from: data)
    }

    /// Проверяет лицензию и возвращает её, если всё в порядке.
    @discardableResult
    public func validate() throws -> License {
        let envelope = try loadEnvelope()
        let expected = LicenseManager.signature(for: envelope.payload)
        guard expected == envelope.signature else {
            throw LicenseError.invalidSignature
        }
        let license = envelope.payload
        if let expiry = license.expiresAt, !expiry.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: expiry), date < Date() {
                throw LicenseError.expired
            }
        }
        guard license.isPro else { throw LicenseError.notPro }
        return license
    }

    public var isFullVersion: Bool {
        (try? validate()) != nil
    }

    // MARK: - Подпись

    /// Канонический байтовый вид полезной нагрузки (тот же порядок ключей,
    /// что и при генерации файла).
    public static func canonicalData(for license: License) -> Data {
        var parts: [String] = []
        parts.append("v1")
        parts.append(license.licenseId)
        parts.append(license.holder)
        parts.append(license.email)
        parts.append(license.level)
        parts.append(license.issuedAt)
        parts.append(license.expiresAt ?? "")
        if let purchase = license.purchase {
            parts.append([
                purchase.date,
                String(format: "%.2f", purchase.amount),
                purchase.currency,
                purchase.receipt,
                purchase.seller,
                purchase.fiscalDocument,
                purchase.documentNumber,
                purchase.sign
            ].joined(separator: "|"))
        } else {
            parts.append("")
        }
        return Data(parts.joined(separator: "\n").utf8)
    }

    public static func signature(for license: License) -> String {
        SHA256.hmacHex(key: signingKey, message: canonicalData(for: license))
    }

    /// Подписывает лицензию и возвращает готовый файл.
    public static func makeEnvelope(for license: License) -> LicenseEnvelope {
        LicenseEnvelope(version: 1, payload: license, signature: signature(for: license))
    }
}
