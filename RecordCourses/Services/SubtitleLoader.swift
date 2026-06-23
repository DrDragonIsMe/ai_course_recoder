import Foundation

struct SubtitleEntry {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum SubtitleLoader {
    static func parse(srt: String) -> [SubtitleEntry] {
        var entries: [SubtitleEntry] = []
        let blocks = srt.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
            guard lines.count >= 3,
                  let index = Int(lines[0]),
                  let (start, end) = parseTimeRange(lines[1]) else { continue }

            let text = lines.dropFirst(2).joined(separator: "\n")
            entries.append(SubtitleEntry(index: index, start: start, end: end, text: text))
        }

        return entries
    }

    private static func parseTimeRange(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2,
              let start = parseTime(parts[0]),
              let end = parseTime(parts[1]) else { return nil }
        return (start, end)
    }

    private static func parseTime(_ string: String) -> TimeInterval? {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
        let components = cleaned.components(separatedBy: ":")
        guard components.count == 3 else { return nil }

        let hourMinute = components[0]
        let minuteSecond = components[1]
        let secondMilli = components[2].replacingOccurrences(of: ",", with: ".")

        guard let hours = Double(hourMinute),
              let minutes = Double(minuteSecond),
              let seconds = Double(secondMilli) else { return nil }

        return hours * 3600 + minutes * 60 + seconds
    }
}
