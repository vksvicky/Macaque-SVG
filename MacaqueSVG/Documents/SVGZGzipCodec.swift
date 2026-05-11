import Foundation
import zlib

/// Gzip (RFC 1952) compress/decompress for `.svgz` (SVG XML compressed with gzip).
enum SVGZGzipCodec {
    enum CodecError: Error, Equatable {
        case notGzip
        case zlib(code: Int32, message: String)

        var presentation: String {
            switch self {
            case .notGzip:
                return "The file does not begin with a gzip header."
            case let .zlib(code, message):
                let detail = message.isEmpty ? "" : ": \(message)"
                return "zlib error \(code)\(detail)"
            }
        }
    }

    static func isGzipMagic(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b
    }

    static func decompress(_ data: Data) throws -> Data {
        guard isGzipMagic(data) else { throw CodecError.notGzip }

        var stream = z_stream()
        let initCode = inflateInit2_(
            &stream,
            MAX_WBITS + 32,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initCode == Z_OK else {
            throw CodecError.zlib(code: initCode, message: stream.msg.map { String(cString: $0) } ?? "inflateInit2")
        }
        defer { inflateEnd(&stream) }

        return try data.withUnsafeBytes { rawIn -> Data in
            guard let inBase = rawIn.bindMemory(to: Bytef.self).baseAddress else {
                throw CodecError.zlib(code: -1, message: "input buffer")
            }
            stream.next_in = UnsafeMutablePointer(mutating: inBase)
            stream.avail_in = uInt(min(rawIn.count, Int(UInt32.max)))

            var output = Data()
            var chunk = [UInt8](repeating: 0, count: 65_536)
            var inflateResult: Int32
            repeat {
                let chunkCount = chunk.count
                inflateResult = chunk.withUnsafeMutableBytes { rawOut -> Int32 in
                    guard let outBase = rawOut.bindMemory(to: Bytef.self).baseAddress else {
                        return Z_DATA_ERROR
                    }
                    stream.next_out = outBase
                    stream.avail_out = uInt(min(chunkCount, Int(UInt32.max)))
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let produced = chunkCount - Int(stream.avail_out)
                if produced > 0 {
                    output.append(chunk, count: produced)
                }
                guard inflateResult == Z_OK || inflateResult == Z_STREAM_END || inflateResult == Z_BUF_ERROR else {
                    let msg = stream.msg.map { String(cString: $0) } ?? ""
                    throw CodecError.zlib(code: inflateResult, message: msg)
                }
            } while inflateResult == Z_OK

            guard inflateResult == Z_STREAM_END else {
                throw CodecError.zlib(code: inflateResult, message: "incomplete gzip stream")
            }
            return output
        }
    }

    static func compress(_ data: Data) throws -> Data {
        var stream = z_stream()
        let initCode = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            MAX_WBITS + 16,
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initCode == Z_OK else {
            throw CodecError.zlib(code: initCode, message: stream.msg.map { String(cString: $0) } ?? "deflateInit2")
        }
        defer { deflateEnd(&stream) }

        return try data.withUnsafeBytes { rawIn -> Data in
            guard let inBase = rawIn.bindMemory(to: Bytef.self).baseAddress else {
                throw CodecError.zlib(code: -1, message: "input buffer")
            }
            stream.next_in = UnsafeMutablePointer(mutating: inBase)
            stream.avail_in = uInt(min(rawIn.count, Int(UInt32.max)))

            var output = Data()
            var chunk = [UInt8](repeating: 0, count: 65_536)
            var deflateResult: Int32
            repeat {
                let chunkCount = chunk.count
                deflateResult = chunk.withUnsafeMutableBytes { rawOut -> Int32 in
                    guard let outBase = rawOut.bindMemory(to: Bytef.self).baseAddress else {
                        return Z_DATA_ERROR
                    }
                    stream.next_out = outBase
                    stream.avail_out = uInt(min(chunkCount, Int(UInt32.max)))
                    return deflate(&stream, Z_FINISH)
                }
                let produced = chunkCount - Int(stream.avail_out)
                if produced > 0 {
                    output.append(chunk, count: produced)
                }
                guard deflateResult == Z_OK || deflateResult == Z_STREAM_END else {
                    let msg = stream.msg.map { String(cString: $0) } ?? ""
                    throw CodecError.zlib(code: deflateResult, message: msg)
                }
            } while deflateResult == Z_OK

            guard deflateResult == Z_STREAM_END else {
                throw CodecError.zlib(code: deflateResult, message: "deflate did not finish")
            }
            return output
        }
    }
}
