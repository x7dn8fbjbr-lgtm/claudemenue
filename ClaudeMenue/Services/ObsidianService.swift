import Foundation

class ObsidianService {
    let vaultPath: URL

    // Default: standard iCloud Obsidian vault location. Adjust to your vault path.
    init(vaultPath: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault")) {
        self.vaultPath = vaultPath
    }

    func createNote(filename: String, content: String, folder: String = "00_INBOX") throws {
        let sanitizedName = filename.hasSuffix(".md") ? filename : "\(filename).md"
        let folderURL = vaultPath.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent(sanitizedName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func updateNote(filename: String, contentToAppend: String) throws {
        let sanitizedName = filename.hasSuffix(".md") ? filename : "\(filename).md"
        let fileURL = try findFile(named: sanitizedName)
        let existing = try String(contentsOf: fileURL, encoding: .utf8)
        let updated = existing + "\n\n" + contentToAppend
        try updated.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func findFile(named filename: String) throws -> URL {
        guard let enumerator = FileManager.default.enumerator(at: vaultPath, includingPropertiesForKeys: nil) else {
            throw ObsidianError.fileNotFound(filename)
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == filename { return url }
        }
        throw ObsidianError.fileNotFound(filename)
    }

    enum ObsidianError: LocalizedError {
        case fileNotFound(String)
        var errorDescription: String? {
            if case .fileNotFound(let name) = self {
                return "Datei '\(name)' nicht im Obsidian Vault gefunden"
            }
            return nil
        }
    }
}
