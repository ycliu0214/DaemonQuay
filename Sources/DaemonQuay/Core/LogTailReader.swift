import Foundation

/// Reads only the portion of a log necessary to display its last `maxLines`.
/// The underlying file is never modified or truncated.
enum LogTailReader {
    static func read(_ url: URL, maxLines: Int = 10_000) throws -> String {
        guard maxLines > 0 else { return "" }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let end = try handle.seekToEnd()
        guard end > 0 else { return "" }
        let chunkSize = 64 * 1024
        var position = end
        var start: UInt64 = 0
        var remainingNewlines = maxLines
        var checkedEnd = false

        while position > 0 {
            let size = Int(min(UInt64(chunkSize), position))
            position -= UInt64(size)
            try handle.seek(toOffset: position)
            let block = try handle.read(upToCount: size) ?? Data()
            guard !block.isEmpty else { break }
            if !checkedEnd {
                // A terminal LF closes the last line; it is not an extra empty line.
                if block.last == 0x0A { remainingNewlines += 1 }
                checkedEnd = true
            }
            for index in block.indices.reversed() where block[index] == 0x0A {
                remainingNewlines -= 1
                if remainingNewlines == 0 {
                    start = position + UInt64(index - block.startIndex + 1)
                    break
                }
            }
            if remainingNewlines == 0 { break }
        }

        try handle.seek(toOffset: start)
        let tail = try handle.readToEnd() ?? Data()
        // Lossy decoding keeps an unusual byte sequence from hiding the entire log.
        return String(decoding: tail, as: UTF8.self)
    }
}
