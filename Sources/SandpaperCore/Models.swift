import Foundation

public enum DocumentFormat: String, Codable, Sendable, CaseIterable {
    case pdf, epub, plainText, markdown, html

    init(fileExtension: String) throws {
        switch fileExtension.lowercased() {
        case "pdf": self = .pdf
        case "epub": self = .epub
        case "txt": self = .plainText
        case "md", "markdown": self = .markdown
        case "html", "htm": self = .html
        default: throw LibraryError.unsupportedFormat(fileExtension)
        }
    }
}

public struct LibraryDocument: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let format: DocumentFormat
    /// SHA-256 of the imported bytes. Future edits create a new revision.
    public let revision: String
    public let importedAt: Date
    public let trashedAt: Date?
}

public struct ImportResult: Equatable, Sendable {
    public let document: LibraryDocument
    public let alreadyImported: Bool
}

/// Resource-relative locations survive EPUB repagination and PDF zoom changes.
public enum SourceResource: Hashable, Codable, Sendable {
    case text
    case pdfPage(index: Int)
    case epub(path: String)
    case article
}

public struct ReadingState: Codable, Equatable, Sendable {
    public let anchor: SourceAnchor
    public let progression: Double

    public init(anchor: SourceAnchor, progression: Double) throws {
        guard progression.isFinite, (0...1).contains(progression) else {
            throw LibraryError.invalidInput("Reading progression must be between zero and one.")
        }
        self.anchor = anchor
        self.progression = progression
    }
}

public enum Familiarity: String, Codable, Sendable, CaseIterable {
    case unfamiliar, learning, known
}

public struct VocabularyEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let expression: String
    public let normalizedExpression: String
    /// A stable lexical sense identifier or an explicitly supplied meaning key.
    public let senseKey: String
    public let meaning: String?
    public let familiarity: Familiarity
    public let notes: String
    public let createdAt: Date
}

public struct VocabularyOccurrence: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let vocabularyID: UUID
    public let anchor: SourceAnchor
    public let explanation: Explanation?
    public let createdAt: Date
}

public enum LibraryError: Error, Equatable, Sendable {
    case unsupportedFormat(String)
    case invalidInput(String)
    case sourceIsNotAFile
    case sourceTooLarge
    case documentNotFound
    case documentInTrash
    case revisionMismatch
    case vocabularyNotFound
    case corruptStoredData
}

enum TextNormalization {
    static func expression(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
