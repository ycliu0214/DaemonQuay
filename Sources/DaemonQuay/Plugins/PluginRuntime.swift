import Foundation

/// The module control executable is invoked once for each action and must exit.
/// Its own service must remain independent from this short-lived control process.
enum PluginRuntime {
    private static func execute(_ plugin: PluginDescriptor, action: String, timeout: Int) -> CommandResult {
        let fm = FileManager.default
        let out = fm.temporaryDirectory.appendingPathComponent("dq-out-\(UUID().uuidString)")
        let err = fm.temporaryDirectory.appendingPathComponent("dq-err-\(UUID().uuidString)")
        guard fm.createFile(atPath: out.path, contents: nil),
              fm.createFile(atPath: err.path, contents: nil),
              let output = FileHandle(forWritingAtPath: out.path),
              let error = FileHandle(forWritingAtPath: err.path) else {
            return CommandResult(code: 2, output: "Could not allocate module response files")
        }
        defer {
            try? output.close()
            try? error.close()
            try? fm.removeItem(at: out)
            try? fm.removeItem(at: err)
        }
        let task = Process()
        task.executableURL = plugin.executable
        task.arguments = [action]
        task.currentDirectoryURL = plugin.directory
        var environment = ProcessInfo.processInfo.environment
        environment["DAEMONQUAY_MODULE_ID"] = plugin.id
        environment["DAEMONQUAY_MODULE_DIR"] = plugin.directory.path
        environment["DAEMONQUAY_DATA_DIR"] = Paths.base.path
        task.environment = environment
        task.standardOutput = output
        task.standardError = error
        let done = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in done.signal() }
        do {
            try task.run()
        } catch {
            return CommandResult(code: 2, output: "Cannot run module: \(error.localizedDescription)")
        }
        if done.wait(timeout: .now() + .seconds(timeout)) == .timedOut {
            // Terminates the module's *control invocation*, not its managed service.
            if task.isRunning { task.terminate() }
            if done.wait(timeout: .now() + .seconds(2)) == .timedOut {
                return CommandResult(code: 2, output: "Module control command timed out and did not exit")
            }
            return CommandResult(code: 2, output: "Module control command timed out after \(timeout)s")
        }
        try? output.synchronize()
        try? error.synchronize()
        guard let data = try? Data(contentsOf: out), data.count <= 65_536,
              let reply = try? JSONDecoder().decode(PluginResponse.self, from: data) else {
            let diagnostic = (try? String(contentsOf: err, encoding: .utf8)) ?? ""
            return CommandResult(code: 2, output: "Invalid module response\(diagnostic.isEmpty ? "" : ": \(String(diagnostic.prefix(300)))")")
        }
        guard task.terminationStatus == 0 else {
            return CommandResult(code: 2, output: reply.message ?? "Module command failed (\(task.terminationStatus))")
        }
        let description = reply.message ?? "\(plugin.name): \(reply.state)"
        switch reply.state {
        case "running": return CommandResult(code: 0, output: description)
        case "stopped": return CommandResult(code: 1, output: description)
        case "external": return CommandResult(code: 3, output: description)
        default: return CommandResult(code: 2, output: description)
        }
    }

    /// Optional, read-only module metadata. Invoke only off the main thread.
    /// This result never changes lifecycle state and is never persisted.
    static func info(_ plugin: PluginDescriptor) -> Result<[String: String], PluginError> {
        guard plugin.supportsInfo else {
            return .failure(.invalid("Module does not support info"))
        }
        let fm = FileManager.default
        let out = fm.temporaryDirectory.appendingPathComponent("dq-info-out-\(UUID().uuidString)")
        let err = fm.temporaryDirectory.appendingPathComponent("dq-info-err-\(UUID().uuidString)")
        guard fm.createFile(atPath: out.path, contents: nil),
              fm.createFile(atPath: err.path, contents: nil),
              let output = FileHandle(forWritingAtPath: out.path),
              let error = FileHandle(forWritingAtPath: err.path) else {
            return .failure(.invalid("Could not allocate info response files"))
        }
        defer {
            try? output.close()
            try? error.close()
            try? fm.removeItem(at: out)
            try? fm.removeItem(at: err)
        }
        let task = Process()
        task.executableURL = plugin.executable
        task.arguments = ["info"]
        task.currentDirectoryURL = plugin.directory
        var environment = ProcessInfo.processInfo.environment
        environment["DAEMONQUAY_MODULE_ID"] = plugin.id
        environment["DAEMONQUAY_MODULE_DIR"] = plugin.directory.path
        environment["DAEMONQUAY_DATA_DIR"] = Paths.base.path
        task.environment = environment
        task.standardOutput = output
        task.standardError = error
        let done = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in done.signal() }
        do {
            try task.run()
        } catch {
            return .failure(.invalid("Cannot run info command: \(error.localizedDescription)"))
        }
        if done.wait(timeout: .now() + .seconds(plugin.infoTimeout)) == .timedOut {
            if task.isRunning { task.terminate() }
            // A control process that ignores termination may survive; never block the GUI indefinitely.
            _ = done.wait(timeout: .now() + .seconds(2))
            return .failure(.invalid("Info command timed out"))
        }
        guard task.terminationStatus == 0 else {
            return .failure(.invalid("Info command failed (exit \(task.terminationStatus))"))
        }
        try? output.synchronize()
        guard let data = try? Data(contentsOf: out), data.count <= 65_536,
              let payload = try? JSONDecoder().decode(PluginInfoResponse.self, from: data),
              payload.values.count <= 100,
              payload.values.allSatisfy({ key, value in
                  key.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil &&
                  value.count <= 4096
              }) else {
            return .failure(.invalid("Invalid info response"))
        }
        return .success(payload.values)
    }

    static func invoke(_ plugin: PluginDescriptor, action: String) -> CommandResult {
        switch action {
        case "status": return execute(plugin, action: action, timeout: plugin.statusTimeout)
        case "validate":
            let result = execute(plugin, action: action, timeout: plugin.statusTimeout + 10)
            return CommandResult(code: result.code == 1 || result.code == 0 ? 0 : 2, output: result.output)
        case "start", "stop":
            let initial = execute(plugin, action: "status", timeout: plugin.statusTimeout)
            if initial.code == 3 || initial.code == 2 { return initial } // fail closed
            if action == "start" && initial.code == 0 { return initial }
            if action == "stop" && initial.code == 1 { return CommandResult(code: 0, output: "Already stopped") }
            let response = execute(plugin, action: action, timeout: action == "start" ? plugin.startTimeout : plugin.stopTimeout)
            if response.code == 2 || response.code == 3 { return response }
            let expected: Int32 = action == "start" ? 0 : 1
            let until = Date().addingTimeInterval(TimeInterval(action == "start" ? plugin.startTimeout : plugin.stopTimeout))
            repeat {
                let check = execute(plugin, action: "status", timeout: plugin.statusTimeout)
                if check.code == expected { return CommandResult(code: 0, output: check.output) }
                if check.code == 2 || check.code == 3 { return check }
                Thread.sleep(forTimeInterval: 0.25)
            } while Date() < until
            return CommandResult(code: 2, output: "\(plugin.name) did not reach \(action == "start" ? "running" : "stopped") state before timeout")
        default: return CommandResult(code: 2, output: "Unknown module action")
        }
    }
}
