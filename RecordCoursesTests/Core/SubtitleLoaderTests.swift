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
}
