import XCTest

@testable import MacaqueSVG

final class SVGZGzipCodecTests: XCTestCase {
    func testRoundTripPreservesUTF8() throws {
        let original = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <rect width="10" height="10" fill="red"/>
        </svg>
        """
        let utf8 = try XCTUnwrap(original.data(using: .utf8))
        let compressed = try SVGZGzipCodec.compress(utf8)
        XCTAssertTrue(SVGZGzipCodec.isGzipMagic(compressed))
        let round = try SVGZGzipCodec.decompress(compressed)
        let decoded = try XCTUnwrap(String(data: round, encoding: .utf8))
        XCTAssertEqual(decoded, original)
    }

    func testDecompressRejectsNonGzip() {
        let plain = Data("not gzip".utf8)
        XCTAssertThrowsError(try SVGZGzipCodec.decompress(plain)) { error in
            XCTAssertEqual(error as? SVGZGzipCodec.CodecError, .notGzip)
        }
    }
}
