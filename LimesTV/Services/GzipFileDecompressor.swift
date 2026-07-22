//
//  GzipFileDecompressor.swift
//  LimesTV
//
//  Streams a gzip file into its decompressed contents using Apple's Compression
//  framework, keeping only small fixed buffers in memory (like Java's
//  GZIPInputStream) rather than loading the whole payload at once.
//

import Compression
import Foundation

enum GzipError: Error {
    case badHeader
    case inflateFailed
    case ioFailed
}

struct GzipFileDecompressor {
    private static let readChunkSize = 64 * 1024
    private static let writeChunkSize = 256 * 1024

    /// Decompresses the gzip file at `source`, streaming the result to `destination`.
    static func decompress(from source: URL, to destination: URL) throws {
        guard let input = InputStream(url: source) else { throw GzipError.ioFailed }
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        guard let output = FileHandle(forWritingAtPath: destination.path) else { throw GzipError.ioFailed }
        input.open()
        defer {
            input.close()
            try? output.close()
        }

        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: writeChunkSize)
        defer { dst.deallocate() }

        // Apple's COMPRESSION_ZLIB works on raw DEFLATE, so we strip the gzip
        // framing ourselves and feed only the DEFLATE payload.
        var stream = compression_stream(dst_ptr: dst, dst_size: writeChunkSize, src_ptr: dst, src_size: 0, state: nil)
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw GzipError.inflateFailed
        }
        defer { compression_stream_destroy(&stream) }
        stream.dst_ptr = dst
        stream.dst_size = writeChunkSize

        var readBuffer = [UInt8](repeating: 0, count: readChunkSize)
        var headerBytes: [UInt8] = []
        var headerParsed = false

        while input.hasBytesAvailable {
            let count = input.read(&readBuffer, maxLength: readChunkSize)
            if count < 0 { throw GzipError.ioFailed }
            if count == 0 { break }

            var payload = ArraySlice(readBuffer[0..<count])

            if !headerParsed {
                headerBytes.append(contentsOf: payload)
                guard headerBytes.count >= 3 else { continue }
                guard headerBytes[0] == 0x1f, headerBytes[1] == 0x8b, headerBytes[2] == 0x08 else {
                    throw GzipError.badHeader
                }
                guard let headerLength = Self.headerLength(headerBytes) else { continue }
                headerParsed = true
                payload = headerBytes[headerLength...]
                headerBytes = []
            }

            try Self.process(Array(payload), finalize: false, stream: &stream, dst: dst, output: output)
        }

        try Self.process([], finalize: true, stream: &stream, dst: dst, output: output)
    }

    /// Feeds one chunk of DEFLATE bytes to the decoder, writing all produced
    /// output. Loops so a chunk that overflows the output buffer is fully drained.
    private static func process(
        _ input: [UInt8],
        finalize: Bool,
        stream: inout compression_stream,
        dst: UnsafeMutablePointer<UInt8>,
        output: FileHandle
    ) throws {
        let flags = finalize ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
        try input.withUnsafeBufferPointer { srcBuf in
            stream.src_ptr = srcBuf.baseAddress ?? UnsafePointer(dst)
            stream.src_size = srcBuf.count

            while true {
                let status = compression_stream_process(&stream, flags)

                let produced = writeChunkSize - stream.dst_size
                if produced > 0 {
                    output.write(Data(bytesNoCopy: dst, count: produced, deallocator: .none))
                    stream.dst_ptr = dst
                    stream.dst_size = writeChunkSize
                }

                switch status {
                case COMPRESSION_STATUS_END:
                    return
                case COMPRESSION_STATUS_OK:
                    // Done with this chunk once its input is consumed (unless we
                    // are finalizing, which runs until END).
                    if flags == 0 && stream.src_size == 0 { return }
                default:
                    throw GzipError.inflateFailed
                }
            }
        }
    }

    /// Returns the length of the gzip header, or `nil` if `bytes` doesn't yet
    /// contain the whole (variable-length) header. Assumes magic already checked.
    private static func headerLength(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 10 else { return nil }
        let flags = bytes[3]
        var index = 10

        if flags & 0x04 != 0 { // FEXTRA
            guard bytes.count >= index + 2 else { return nil }
            let xlen = Int(bytes[index]) | (Int(bytes[index + 1]) << 8)
            index += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME (zero-terminated)
            while true {
                guard index < bytes.count else { return nil }
                let byte = bytes[index]; index += 1
                if byte == 0 { break }
            }
        }
        if flags & 0x10 != 0 { // FCOMMENT (zero-terminated)
            while true {
                guard index < bytes.count else { return nil }
                let byte = bytes[index]; index += 1
                if byte == 0 { break }
            }
        }
        if flags & 0x02 != 0 { index += 2 } // FHCRC

        return index <= bytes.count ? index : nil
    }
}
