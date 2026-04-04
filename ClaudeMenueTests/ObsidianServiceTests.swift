import XCTest
@testable import ClaudeMenue

final class ObsidianServiceTests: XCTestCase {
    var tempDir: URL!
    var service: ObsidianService!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = ObsidianService(vaultPath: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_createNote_schreibtDateiInInbox() throws {
        try service.createNote(filename: "test-notiz", content: "# Test\nInhalt")

        let fileURL = tempDir.appendingPathComponent("00_INBOX/test-notiz.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, "# Test\nInhalt")
    }

    func test_createNote_haengtMdAnWennFehlt() throws {
        try service.createNote(filename: "ohne-endung", content: "Inhalt")
        let fileURL = tempDir.appendingPathComponent("00_INBOX/ohne-endung.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func test_createNote_benutztBenutzerdefiniertordner() throws {
        try service.createNote(filename: "notiz", content: "Inhalt", folder: "10_Projects")
        let fileURL = tempDir.appendingPathComponent("10_Projects/notiz.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func test_updateNote_haengtTextAn() throws {
        let folderURL = tempDir.appendingPathComponent("00_INBOX")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent("vorhandene.md")
        try "# Bestehend\nAlt".write(to: fileURL, atomically: true, encoding: .utf8)

        try service.updateNote(filename: "vorhandene.md", contentToAppend: "Neu hinzugefügt")

        let result = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(result, "# Bestehend\nAlt\n\nNeu hinzugefügt")
    }

    func test_updateNote_wirftFehlerWennDateiNichtExistiert() {
        XCTAssertThrowsError(try service.updateNote(filename: "nicht-vorhanden.md", contentToAppend: "Text")) { error in
            XCTAssertTrue(error is ObsidianService.ObsidianError)
        }
    }
}
