import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// Executed only on explicit module operations. This is not a persistent helper or daemon.
// Any module implementing the JSON start/stop/status contract can replace this executable.
struct OptionalArgumentGroup: Decodable {
    let whenNonEmpty: String
    let arguments: [String]
}
struct ControlSpec: Decodable {
    let apiVersion: Int
    let launchLabel: String
    let start: [String]
    let optionalStartArguments: [OptionalArgumentGroup]?
    let preflight: [String]?
    let requiredDirectories: [String]?
    let requiredFiles: [String]?
    let stopStrategy: String
    let stopCommand: [String]?
    let portKey: String?
    let timeoutKey: String?
}
struct Response: Encodable {
    let state: String
    let message: String
}
struct Failure: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
struct ResultCode {
    let code: Int32
    let output: String
}

struct ModuleHost {
    let id: String
    let base: URL
    let directory: URL
    let spec: ControlSpec
    let config: [String: Any]

    var domain: String { "gui/\(getuid())" }
    var job: String { "\(domain)/\(spec.launchLabel)" }
    var plistURL: URL { base.appendingPathComponent("agents/\(spec.launchLabel).plist") }

    static func load() throws -> ModuleHost {
        let env = ProcessInfo.processInfo.environment
        guard let id = env["DAEMONQUAY_MODULE_ID"],
              id.range(of: "^[a-z][a-z0-9-]{1,39}$", options: .regularExpression) != nil,
              let dir = env["DAEMONQUAY_MODULE_DIR"],
              let root = env["DAEMONQUAY_DATA_DIR"] else {
            throw Failure(reason: "Missing DaemonQuay module environment")
        }
        let directory = URL(fileURLWithPath: dir, isDirectory: true)
        let base = URL(fileURLWithPath: root, isDirectory: true)
        let spec = try JSONDecoder().decode(ControlSpec.self,
            from: Data(contentsOf: directory.appendingPathComponent("service.json")))
        guard spec.apiVersion == 1,
              spec.launchLabel == "dev.daemonquay.\(id)",
              !spec.start.isEmpty, ["signal", "commandThenSignal"].contains(spec.stopStrategy),
              spec.stopStrategy != "commandThenSignal" || (spec.stopCommand?.isEmpty == false) else {
            throw Failure(reason: "Invalid service lifecycle definition")
        }
        let data = try Data(contentsOf: base.appendingPathComponent("settings.json"))
        guard let rootJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = rootJSON[id] as? [String: Any] else {
            throw Failure(reason: "Missing settings for module \(id)")
        }
        return ModuleHost(id: id, base: base, directory: directory, spec: spec, config: config)
    }
    func expand(_ value: String) throws -> String {
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index...].hasPrefix("${"),
               let closing = value[index...].firstIndex(of: "}") {
                let key = String(value[value.index(index, offsetBy: 2)..<closing])
                guard key.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil,
                      let raw = config[key] else { throw Failure(reason: "Missing setting: \(key)") }
                result += "\(raw)"
                index = value.index(after: closing)
            } else {
                result.append(value[index])
                index = value.index(after: index)
            }
        }
        if result == "~" { return NSHomeDirectory() }
        if result.hasPrefix("~/") { return NSHomeDirectory() + String(result.dropFirst()) }
        return result
    }
    func expand(_ args: [String]) throws -> [String] { try args.map(expand) }
    func number(_ key: String?, fallback: Int) throws -> Int {
        guard let key else { return fallback }
        guard let n = config[key] as? Int else { throw Failure(reason: "Invalid integer setting: \(key)") }
        return n
    }
    func startArguments() throws -> [String] {
        var args = try expand(spec.start)
        for group in spec.optionalStartArguments ?? [] {
            let setting = config[group.whenNonEmpty].map { "\($0)" } ?? ""
            if !setting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args += try expand(group.arguments)
            }
        }
        return args
    }
    func validate() throws {
        let start = try startArguments()
        guard let program = start.first, program.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: program) else {
            throw Failure(reason: "Executable does not exist or is not executable: \(start.first ?? "")")
        }
        let port = try number(spec.portKey, fallback: 0)
        if spec.portKey != nil && !(1...65535).contains(port) { throw Failure(reason: "Port must be between 1 and 65535") }
        let timeout = try number(spec.timeoutKey, fallback: 60)
        if !(10...300).contains(timeout) { throw Failure(reason: "Shutdown timeout must be 10–300 seconds") }
        // A missing SSD cache directory is fine when the user disables that optional feature.
        if let cache = config["ssdCacheDirectory"] as? String,
           !cache.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let size = (config["ssdCacheMaxSize"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !size.isEmpty else { throw Failure(reason: "SSD cache max size is required when SSD cache is enabled") }
            let path = try expand(cache)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else { throw Failure(reason: "SSD cache path is not a directory: \(path)") }
            } else {
                // Only the bundled default is prepared automatically. User-selected
                // cache locations must already exist to avoid unintended filesystem writes.
                guard cache == "~/.omlx/cache" else {
                    throw Failure(reason: "SSD cache directory not found: \(path). Create it or clear the cache path to disable SSD cache.")
                }
                let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
                var parentIsDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: parent, isDirectory: &parentIsDirectory),
                      parentIsDirectory.boolValue,
                      FileManager.default.isWritableFile(atPath: parent) else {
                    throw Failure(reason: "Cannot prepare default SSD cache directory: \(path). Check ~/.omlx or disable SSD cache.")
                }
            }
        }
        for raw in spec.requiredDirectories ?? [] {
            let path = try expand(raw)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw Failure(reason: "Required directory not found: \(path)")
            }
        }
        for raw in spec.requiredFiles ?? [] {
            let path = try expand(raw)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw Failure(reason: "Required file not found: \(path)")
            }
        }
        if let preflight = spec.preflight {
            let expanded = try expand(preflight)
            guard let first = expanded.first, FileManager.default.isExecutableFile(atPath: first) else {
                throw Failure(reason: "Invalid preflight executable")
            }
        }
        if let stop = spec.stopCommand {
            let expanded = try expand(stop)
            guard let first = expanded.first, FileManager.default.isExecutableFile(atPath: first) else {
                throw Failure(reason: "Invalid stop executable")
            }
        }
    }

    // Command output is redirected to a file so no child can deadlock on a full Pipe.
    func run(_ argv: [String], timeout: Int = 15) -> ResultCode {
        guard let executable = argv.first else { return ResultCode(code: 127, output: "Empty command") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dq-cmd-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil),
              let output = FileHandle(forWritingAtPath: url.path) else {
            return ResultCode(code: 127, output: "Could not allocate command output")
        }
        defer { try? output.close(); try? FileManager.default.removeItem(at: url) }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = Array(argv.dropFirst())
        task.standardOutput = output
        task.standardError = output
        let finished = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in finished.signal() }
        do { try task.run() } catch { return ResultCode(code: 127, output: error.localizedDescription) }
        if finished.wait(timeout: .now() + .seconds(timeout)) == .timedOut {
            if task.isRunning { task.terminate() }
            _ = finished.wait(timeout: .now() + .seconds(2))
            return ResultCode(code: 124, output: "Command timed out")
        }
        let data = (try? Data(contentsOf: url)) ?? Data()
        return ResultCode(code: task.terminationStatus,
                          output: String(decoding: data.prefix(32_768), as: UTF8.self))
    }
    func launchctl(_ args: [String]) -> ResultCode { run(["/bin/launchctl"] + args) }
    func must(_ r: ResultCode) throws {
        guard r.code == 0 else { throw Failure(reason: r.output.isEmpty ? "Command failed (\(r.code))" : r.output) }
    }
    func registered() -> Bool { launchctl(["print", job]).code == 0 }
    func pid() -> Int32? {
        let answer = launchctl(["print", job])
        guard answer.code == 0 else { return nil }
        for line in answer.output.components(separatedBy: .newlines) {
            let part = line.trimmingCharacters(in: .whitespaces)
            if part.hasPrefix("pid = "), let n = Int32(part.dropFirst(6)), n > 0 {
                if kill(n, 0) == 0 || errno == EPERM { return n }
            }
        }
        return nil
    }
    func portBusy() throws -> Bool {
        guard spec.portKey != nil else { return false }
        let port = try number(spec.portKey, fallback: 0)
        return run(["/usr/sbin/lsof", "-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]).code == 0
    }
    func status() throws -> Response {
        if let n = pid() { return Response(state: "running", message: "Running (PID \(n))") }
        if try portBusy() { return Response(state: "external", message: "Another process is listening on this port") }
        return Response(state: "stopped", message: "Stopped")
    }
    func generate() throws {
        let fm = FileManager.default
        let logs = base.appendingPathComponent("logs/\(id)", isDirectory: true)
        let agents = base.appendingPathComponent("agents", isDirectory: true)
        try fm.createDirectory(at: logs, withIntermediateDirectories: true)
        try fm.createDirectory(at: agents, withIntermediateDirectories: true)
        let args = try startArguments()
        let timeout = try number(spec.timeoutKey, fallback: 60)
        let plist: [String: Any] = [
            "Label": spec.launchLabel,
            "ProgramArguments": args,
            "RunAtLoad": false,
            "KeepAlive": false,
            "ExitTimeOut": timeout,
            "WorkingDirectory": NSHomeDirectory(),
            "StandardOutPath": logs.appendingPathComponent("log.log").path,
            "StandardErrorPath": logs.appendingPathComponent("error.log").path
        ]
        let encoded = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try encoded.write(to: plistURL, options: .atomic)
    }
    func start() throws -> Response {
        try validate()
        let current = try status()
        if current.state == "running" { return current }
        if current.state == "external" { return current }
        if id == "omlx", let cache = config["ssdCacheDirectory"] as? String,
           cache == "~/.omlx/cache" {
            // The ordinary first-run default is created only when actually starting.
            try FileManager.default.createDirectory(atPath: try expand(cache), withIntermediateDirectories: true)
        }
        if let preflight = spec.preflight { try must(run(try expand(preflight), timeout: 20)) }
        try generate()
        if registered() { try must(launchctl(["bootout", job])) }
        try must(launchctl(["bootstrap", domain, plistURL.path]))
        do { try must(launchctl(["kickstart", job])) }
        catch { _ = launchctl(["bootout", job]); throw error }
        let deadline = Date().addingTimeInterval(10)
        repeat {
            if let n = pid() { return Response(state: "running", message: "Started (PID \(n))") }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        throw Failure(reason: "Service did not start; inspect its logs")
    }
    func stop() throws -> Response {
        let current = try status()
        if current.state == "external" { return current }
        if current.state == "stopped" {
            if registered() { try must(launchctl(["bootout", job])) }
            return current
        }
        if spec.stopStrategy == "commandThenSignal", let cmd = spec.stopCommand {
            if run(try expand(cmd), timeout: 15).code != 0 {
                try must(launchctl(["kill", "SIGTERM", job]))
            }
        } else {
            try must(launchctl(["kill", "SIGTERM", job]))
        }
        let seconds = try number(spec.timeoutKey, fallback: 60)
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        repeat {
            if pid() == nil {
                if registered() { try must(launchctl(["bootout", job])) }
                return Response(state: "stopped", message: "Stopped gracefully")
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        throw Failure(reason: "Service still running after \(seconds)s; will not force kill")
    }
}

do {
    let host = try ModuleHost.load()
    let action = CommandLine.arguments.dropFirst().first ?? ""
    let response: Response
    switch action {
    case "status": response = try host.status()
    case "start": response = try host.start()
    case "stop": response = try host.stop()
    case "validate":
        try host.validate()
        response = Response(state: "stopped", message: "Configuration valid")
    default: throw Failure(reason: "Unknown module action: \(action)")
    }
    let encoded = try JSONEncoder().encode(response)
    FileHandle.standardOutput.write(encoded)
    FileHandle.standardOutput.write(Data([0x0A]))
} catch {
    let response = Response(state: "error", message: error.localizedDescription)
    if let data = try? JSONEncoder().encode(response) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
    exit(1)
}
