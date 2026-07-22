//
//  XMLTVParser.swift
//  LimesTV
//
//  SAX-style parser for the XMLTV programme guide. Reads a stream incrementally
//  and extracts `<programme>` elements grouped by channel id, so the ~9 MB guide
//  never sits fully in memory.
//

import Foundation

final class XMLTVParser: NSObject, XMLParserDelegate {
    private var programmes: [String: [EPGProgramme]] = [:]

    private var currentChannelId: String?
    private var currentStart: Date?
    private var currentStop: Date?
    private var titleText = ""
    private var descText = ""
    private var capturingTitle = false
    private var capturingDesc = false

    /// XMLTV timestamps look like "20260722060000 +0200".
    private let zonedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        return formatter
    }()
    private let plainDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }()

    /// Parses the stream and returns the grouped, start-sorted guide.
    func parse(stream: InputStream) -> EPGGuide {
        let parser = XMLParser(stream: stream)
        parser.delegate = self
        parser.parse()
        let sorted = programmes.mapValues { $0.sorted { $0.start < $1.start } }
        return EPGGuide(programmes: sorted)
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string?.trimmingCharacters(in: .whitespaces), !string.isEmpty else { return nil }
        return zonedDateFormatter.date(from: string) ?? plainDateFormatter.date(from: string)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "programme":
            currentChannelId = attributeDict["channel"]
            currentStart = parseDate(attributeDict["start"])
            currentStop = parseDate(attributeDict["stop"])
            titleText = ""
            descText = ""
        case "title":
            capturingTitle = true
            titleText = ""
        case "desc":
            capturingDesc = true
            descText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingTitle {
            titleText += string
        } else if capturingDesc {
            descText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "title":
            capturingTitle = false
        case "desc":
            capturingDesc = false
        case "programme":
            defer {
                currentChannelId = nil
                currentStart = nil
                currentStop = nil
                titleText = ""
                descText = ""
            }
            guard let channelId = currentChannelId,
                  let start = currentStart,
                  let stop = currentStop else { return }
            let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let description = descText.trimmingCharacters(in: .whitespacesAndNewlines)
            let programme = EPGProgramme(
                channelId: channelId,
                title: title,
                description: description.isEmpty ? nil : description,
                start: start,
                stop: stop
            )
            programmes[channelId, default: []].append(programme)
        default:
            break
        }
    }
}
