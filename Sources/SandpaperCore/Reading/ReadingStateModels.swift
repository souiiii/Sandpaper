import Foundation

public enum MeaningSource: Codable, Equatable, Sendable {
    case personal
    case dictionary(provider: String, entryID: String)
    case aiInterpretation
}

public struct ReadingPosition: Codable, Equatable, Sendable {
    public let documentID: UUID
    public let revision: String
    public let resource: SourceResource
    public let anchor: SourceAnchor?
    public let progression: Double

    public init(documentID: UUID, revision: String, resource: SourceResource, anchor: SourceAnchor? = nil, progression: Double) throws {
        guard !revision.isEmpty, progression.isFinite, (0...1).contains(progression),
              anchor.map({ $0.documentID == documentID && $0.revision == revision && $0.resource == resource }) ?? true else {
            throw LibraryError.invalidInput("Invalid reading position.")
        }
        self.documentID = documentID; self.revision = revision; self.resource = resource
        self.anchor = anchor; self.progression = progression
    }
}

public struct Bookmark: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let position: ReadingPosition
    public let title: String
    public let createdAt: Date
}

public struct ReadingPreferences: Codable, Equatable, Sendable {
    public enum Theme: String, Codable, Sendable { case system, light, dark }
    public var fontName: String?
    public var fontSize: Double
    public var lineHeight: Double
    public var theme: Theme

    public init(fontName: String? = nil, fontSize: Double = 18, lineHeight: Double = 1.5, theme: Theme = .system) {
        self.fontName = fontName; self.fontSize = fontSize; self.lineHeight = lineHeight; self.theme = theme
    }

    func validate() throws {
        guard fontSize.isFinite, (10...96).contains(fontSize), lineHeight.isFinite, (1...3).contains(lineHeight),
              fontName.map({ !$0.isEmpty && $0.utf16.count <= 256 }) ?? true else { throw LibraryError.invalidInput("Invalid reading preferences.") }
    }
}
