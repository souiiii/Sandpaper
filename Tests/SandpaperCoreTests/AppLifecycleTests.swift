import AppKit
import Foundation
import Testing
@testable import SandpaperCore

/// Explicit integration check of the actual bundled AppKit process, with no windows.
@Suite(.serialized)
@MainActor
struct AppLifecycleTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SANDPAPER_APP_BUNDLE"] != nil))
    func bundleHandlesFinderOpenAndRestoresAfterNormalQuit() async throws {
        let builtBundle = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SANDPAPER_APP_BUNDLE"]!)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("Sandpaper.app")
        try FileManager.default.copyItem(at: builtBundle, to: bundle)
        let source = root.appendingPathComponent("Lifecycle book.md")
        try Data("# A chapter\n\nA reader returns to **saved passages**.".utf8).write(to: source)
        struct Asset: Decodable { let file: String; let term: String }
        var inputs: [(url: URL, term: String)] = [(source, "saved passages")]
        if let path = ProcessInfo.processInfo.environment["SANDPAPER_LIVE_ASSETS"] {
            let assets = URL(fileURLWithPath: path)
            for item in try JSONDecoder().decode([Asset].self, from: Data(contentsOf: assets.appendingPathComponent("assets.json"))) {
                inputs.append((assets.appendingPathComponent(item.file), item.term))
            }
        }
        let location = root.appendingPathComponent("Library")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.environment = ["SANDPAPER_LIBRARY_DIRECTORY": location.path, "SANDPAPER_LLAMA_PORT": "invalid"]
        let first = try await NSWorkspace.shared.open(inputs.map(\.url), withApplicationAt: bundle, configuration: configuration)
        defer { if !first.isTerminated { first.forceTerminate() } }
        let state = location.appendingPathComponent("OpenReaders.json")
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        var ids: [UUID] = []
        while ids.count != inputs.count {
            if let data = try? Data(contentsOf: state) { ids = (try? JSONDecoder().decode([UUID].self, from: data)) ?? [] }
            guard ContinuousClock.now < deadline else { throw LifecycleTestError.timedOut }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(first.activationPolicy == .accessory)
        let library = try DocumentLibrary(directory: location)
        #expect(try await library.documents().count == inputs.count)
        var saved: [(occurrence: UUID, range: NSRange)] = []
        for (id, input) in zip(ids, inputs) {
            let reader = ReaderSession(library: library)
            let book = try await reader.open(documentID: id)
            var found: (SourceResource, NSRange)?
            for resource in book.resources {
                let content = try await reader.content(for: resource.source)
                let range = (content.text as NSString).range(of: input.term, options: .caseInsensitive)
                if found == nil, range.location != NSNotFound { found = (resource.source, range) }
            }
            let (resource, range) = try #require(found)
            let selection = try await reader.select(documentID: id, resource: resource, range: range)
            let meaning: VocabularyMeaningChoice
            if input.url == source { meaning = .personal("A stored location in the book") }
            else {
                let entry = try #require(await reader.lookup(selectionID: selection.id).first)
                let excerpt = String(entry.text.prefix(500))
                meaning = .dictionary(entryID: entry.id, range: NSRange(location: 0, length: excerpt.utf16.count))
            }
            let occurrence = try await reader.save(selectionID: selection.id, meaning: meaning)
            let bookmark = try await reader.bookmark(documentID: id, resource: resource, range: range, title: input.term)
            try await reader.recordProgress(documentID: id, resource: resource, visibleRange: range, progression: 0.6)
            #expect(try await reader.navigate(to: bookmark.position).resolution == .exact(range))
            saved.append((occurrence.id, range))
        }
        #expect(first.terminate())
        try await waitForExit(first)
        let priorModification = try #require(try state.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        let second = try await NSWorkspace.shared.openApplication(at: bundle, configuration: configuration)
        defer { if !second.isTerminated { second.forceTerminate() } }
        let restoreDeadline = ContinuousClock.now.advanced(by: .seconds(15))
        while (try state.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) <= priorModification {
            guard ContinuousClock.now < restoreDeadline else { throw LifecycleTestError.timedOut }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(try JSONDecoder().decode([UUID].self, from: Data(contentsOf: state)) == ids)
        for item in saved {
            let occurrence = try await library.occurrence(id: item.occurrence)
            #expect(try await library.readingPosition(for: occurrence.anchor.documentID)?.progression == 0.6)
            let reader = ReaderSession(library: library)
            #expect(try await reader.navigate(to: occurrence).resolution == .exact(item.range))
        }
        #expect(second.terminate())
        try await waitForExit(second)
        #expect(try JSONDecoder().decode([UUID].self, from: Data(contentsOf: state)) == ids)
    }

    private func waitForExit(_ application: NSRunningApplication) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while !application.isTerminated {
            guard ContinuousClock.now < deadline else { throw LifecycleTestError.timedOut }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private enum LifecycleTestError: Error { case timedOut }
