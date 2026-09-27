import XCTest
import UniformTypeIdentifiers
@testable import Biqli

final class BiqliModelsTests: XCTestCase {
    private let exampleHandoffURL = URL(
        string: "https://go.example.com/m/handoff?biqli_token=bqmh_" +
            String(repeating: "a", count: 43)
    )!

    func testNoMatchResponseDecodes() throws {
        let data = #"{"open":{"id":"biq_open_01","firstOpen":true,"matchedBy":"none","confidence":"none"},"click":null,"link":null,"attribution":null,"requestId":"req_01"}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(BiqliAttributionResult.self, from: data)
        XCTAssertEqual(result.open.matchedBy, .none)
        XCTAssertNil(result.attribution)
    }

    func testSafariClipboardHandoffTextDecodesAsURL() throws {
        let expected = exampleHandoffURL
        let clipboardData = try XCTUnwrap(expected.absoluteString.data(using: .utf8))

        XCTAssertEqual(BiqliPasteItemLoader.url(from: clipboardData), expected)
    }

    func testClipboardDecoderTrimsFormattingCharacters() throws {
        let expected = exampleHandoffURL
        let clipboardData = try XCTUnwrap(
            "\u{FEFF}  \(expected.absoluteString)\n\u{0000}".data(using: .utf8)
        )

        XCTAssertEqual(BiqliPasteItemLoader.url(from: clipboardData), expected)
    }

    func testSafariStyleItemProviderLoadsHandoffURL() throws {
        let expected = exampleHandoffURL
        let clipboardData = try XCTUnwrap(expected.absoluteString.data(using: .utf8))
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.utf8PlainText.identifier,
            visibility: .all
        ) { completion in
            completion(clipboardData, nil)
            return nil
        }
        let loaded = expectation(description: "Loads the UTF-8 paste representation")

        BiqliPasteItemLoader.loadURL(from: [provider]) { url in
            XCTAssertEqual(url, expected)
            loaded.fulfill()
        }

        wait(for: [loaded], timeout: 1)
    }
}
