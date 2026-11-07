import AppKit
import Foundation
import OSLog
import SandpaperCore

/// Lifecycle only. Reader windows and menus are deliberately not part of this target yet.
@MainActor
final class SandpaperAppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.sandpaper.reader", category: "application")
    private var startup: Task<ReaderWorkspace, Error>?
    private var requests: [UUID: Task<Void, Never>] = [:]
    private var lastRequest: Task<Void, Never>?
    private var terminating = false

    private func workspace() -> Task<ReaderWorkspace, Error> {
        if let startup { return startup }
        let environment = ProcessInfo.processInfo.environment
        let logger = logger
        let task = Task.detached {
            let directory: URL
            if let path = environment["SANDPAPER_LIBRARY_DIRECTORY"], !path.isEmpty {
                directory = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true).appendingPathComponent("Sandpaper", isDirectory: true)
            }
            let engine: any LocalAnalysisEngine
            if let portText = environment["SANDPAPER_LLAMA_PORT"] {
                if let port = Int(portText),
                   let format = LocalChatFormat(rawValue: environment["SANDPAPER_CHAT_FORMAT"] ?? "gemma3"),
                   let configuration = try? LlamaServerConfiguration(port: port, chatFormat: format) {
                    engine = LlamaLocalEngine(configuration: configuration)
                } else {
                    logger.error("Ignoring invalid optional local AI configuration; reading remains available.")
                    engine = UnconfiguredLocalEngine()
                }
            } else { engine = UnconfiguredLocalEngine() }
            let workspace = try ReaderWorkspace(directory: directory, engine: engine)
            do {
                for issue in try await workspace.restore() {
                    logger.error("Could not restore reader \(issue.documentID): \(issue.message, privacy: .public)")
                }
            } catch {
                logger.error("Could not restore the open-reader list: \(String(describing: error), privacy: .public)")
            }
            return workspace
        }
        startup = task
        return task
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = workspace()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !terminating else { sender.reply(toOpenOrPrint: .failure); return }
        let startup = workspace()
        let previous = lastRequest
        let id = UUID()
        let task = Task { [weak self] in
            _ = await previous?.result
            var succeeded = true
            do {
                try Task.checkCancellation()
                let workspace = try await startup.value
                for filename in filenames {
                    try Task.checkCancellation()
                    do { _ = try await workspace.open(from: URL(fileURLWithPath: filename)) }
                    catch is CancellationError { throw CancellationError() }
                    catch {
                        succeeded = false
                        self?.logger.error("Document open failed: \(String(describing: error), privacy: .public)")
                    }
                }
            } catch {
                succeeded = false
                self?.logger.error("Document request failed: \(String(describing: error), privacy: .public)")
            }
            sender.reply(toOpenOrPrint: succeeded ? .success : .failure)
            self?.requests.removeValue(forKey: id)
        }
        requests[id] = task
        lastRequest = task
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        let pending = Array(requests.values)
        pending.forEach { $0.cancel() }
        let startup = startup
        Task {
            for task in pending { await task.value }
            do { if let startup { try await startup.value.shutdown() } }
            catch { logger.error("Shutdown failed: \(String(describing: error), privacy: .public)") }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
enum SandpaperApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = SandpaperAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
