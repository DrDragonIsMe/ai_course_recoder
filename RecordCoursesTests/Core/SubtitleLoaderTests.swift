import Testing
import Foundation
@testable import RecordCourses

@Suite("Subtitle Loader Tests")
struct SubtitleLoaderTests {

    @Test("Subtitle loader parses SRT")
    func subtitleLoaderParsesSRT() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        2
        00:00:04,000 --> 00:00:06,000
        World
        """
        let entries = SubtitleLoader.parse(srt: srt)
        #expect(entries.count == 2)
        #expect(entries[0].text == "Hello")
        #expect(entries[1].text == "World")
        #expect(entries[0].start == 1)
        #expect(entries[1].start == 4)
    }

    @Test("Subtitle loader ignores malformed blocks")
    func subtitleLoaderIgnoresMalformedBlocks() {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,000
        Valid

        malformed block
        """
        let entries = SubtitleLoader.parse(srt: srt)
        #expect(entries.count == 1)
        #expect(entries[0].text == "Valid")
    }

    @Test("Subtitle selector returns active entry")
    func subtitleSelectorReturnsActiveEntry() {
        let entries = [
            SubtitleEntry(index: 1, start: 1, end: 3, text: "Hello"),
            SubtitleEntry(index: 2, start: 4, end: 6, text: "World")
        ]
        #expect(SubtitleLoader.subtitle(for: 2, entries: entries).primary == "Hello")
        #expect(SubtitleLoader.subtitle(for: 5, entries: entries).primary == "World")
    }

    @Test("Subtitle selector returns empty outside ranges")
    func subtitleSelectorReturnsEmptyOutsideRanges() {
        let entries = [SubtitleEntry(index: 1, start: 1, end: 3, text: "Hello")]
        #expect(SubtitleLoader.subtitle(for: 0, entries: entries).primary.isEmpty)
        #expect(SubtitleLoader.subtitle(for: 3, entries: entries).primary.isEmpty)
    }

    @Test("Subtitle selector splits bilingual text")
    func subtitleSelectorSplitsBilingualText() {
        let entries = [SubtitleEntry(index: 1, start: 0, end: 2, text: "Hello\nBonjour")]
        let result = SubtitleLoader.subtitle(for: 1, entries: entries, bilingual: true)
        #expect(result.primary == "Hello")
        #expect(result.secondary == "Bonjour")
    }
}
