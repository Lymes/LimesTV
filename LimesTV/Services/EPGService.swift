//
//  EPGService.swift
//  LimesTV
//
//  Downloads the gzipped XMLTV programme guide, decompresses and parses it as a
//  stream (low memory), and returns the resulting guide. No main-thread work.
//

import Foundation
import OSLog

private let epgLog = Logger(subsystem: "com.lymes.LimesTV", category: "EPG")

enum EPGError: Error {
    case badResponse
    case parseFailed
}

nonisolated struct EPGService {
    /// Short URL that redirects to the current gzipped XMLTV guide.
    static let sourceURL = URL(string: "https://www.epgitalia.tv/guide2")!

    /// Fetches, decompresses and parses the programme guide. Downloads to a
    /// temporary file and streams both the gunzip and the XML parse so the ~9 MB
    /// payload never sits fully in memory.
    func fetchGuide() async throws -> EPGGuide {
        var request = URLRequest(url: Self.sourceURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        // A dedicated session that doesn't auto-follow redirects, so we can turn
        // the HTTPS→HTTP downgrade into a direct top-level HTTP request (ATS
        // blocks the downgrade only when it happens mid-redirect).
        let session = URLSession(configuration: .default, delegate: RedirectBlockingDelegate(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let targetURL = try await resolveRedirect(from: request, session: session)

        var fileRequest = URLRequest(url: targetURL)
        fileRequest.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        fileRequest.timeoutInterval = 60

        epgLog.log("Downloading guide from \(targetURL.absoluteString, privacy: .public)")
        let downloadedURL: URL
        let response: URLResponse
        do {
            (downloadedURL, response) = try await session.download(for: fileRequest)
        } catch {
            epgLog.error("Download failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        defer { try? FileManager.default.removeItem(at: downloadedURL) }

        let http = response as? HTTPURLResponse
        let downloadedSize = (try? FileManager.default.attributesOfItem(atPath: downloadedURL.path)[.size] as? Int) ?? nil
        epgLog.log("""
            Download OK status=\(http?.statusCode ?? -1) \
            contentType=\(http?.value(forHTTPHeaderField: "Content-Type") ?? "?", privacy: .public) \
            bytes=\(downloadedSize ?? -1)
            """)

        if let http, !(200..<300).contains(http.statusCode) {
            epgLog.error("Bad HTTP status \(http.statusCode)")
            throw EPGError.badResponse
        }

        let xmlURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xml")
        defer { try? FileManager.default.removeItem(at: xmlURL) }

        do {
            try GzipFileDecompressor.decompress(from: downloadedURL, to: xmlURL)
        } catch {
            epgLog.error("Gunzip failed: \(String(describing: error), privacy: .public)")
            throw error
        }
        let xmlSize = (try? FileManager.default.attributesOfItem(atPath: xmlURL.path)[.size] as? Int) ?? nil
        epgLog.log("Decompressed to \(xmlSize ?? -1) bytes")

        guard let stream = InputStream(url: xmlURL) else {
            epgLog.error("Could not open XML stream")
            throw EPGError.parseFailed
        }
        let guide = XMLTVParser().parse(stream: stream)
        let channels = guide.programmes.count
        let programmes = guide.programmes.values.reduce(0) { $0 + $1.count }
        epgLog.log("Parsed \(programmes) programmes across \(channels) channels")
        return guide
    }

    /// Resolves a single redirect: requests `request` without following, and
    /// returns the `Location` target if it's a redirect, otherwise the original
    /// URL (the endpoint already served content directly).
    private func resolveRedirect(from request: URLRequest, session: URLSession) async throws -> URL {
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EPGError.badResponse }

        if (300..<400).contains(http.statusCode),
           let location = http.value(forHTTPHeaderField: "Location"),
           let target = URL(string: location) {
            epgLog.log("Redirect \(http.statusCode) -> \(target.absoluteString, privacy: .public)")
            return target
        }
        return request.url ?? Self.sourceURL
    }
}
