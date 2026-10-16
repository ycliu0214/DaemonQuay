import Foundation
@main struct Harness {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        FileHandle.standardOutput.write(Data(try LogTailReader.read(url).utf8))
    }
}
