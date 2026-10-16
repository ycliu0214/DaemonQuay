import Foundation
import Darwin

/// Single instance per macOS user. The kernel releases the advisory lock if the
/// GUI crashes or is force-quit. Never unlink the lock file: doing so can allow
/// different processes to lock different inodes at the same path.
@MainActor
final class SingleInstanceGuard {
    static let shared = SingleInstanceGuard()

    private var lockFD: Int32 = -1
    private let notificationName = Notification.Name("local.daemonquay.manager.showExisting")
    private var observer: NSObjectProtocol?

    private init() {}

    /// Returns false when another DaemonQuay instance owns the lock.
    func acquire(onReopen: @escaping @MainActor () -> Void) -> Bool {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/DaemonQuay", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("DaemonQuay: cannot create instance-lock directory: %@", String(describing: error))
            return false // Fail closed: don't start an unprotected GUI.
        }

        let path = directory.appendingPathComponent("gui.lock").path
        let fd = path.withCString { open($0, O_RDWR | O_CREAT | O_CLOEXEC, mode_t(0o600)) }
        guard fd >= 0 else {
            NSLog("DaemonQuay: cannot open instance lock (errno=%d)", errno)
            return false
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            // The lock is held by the existing instance. Inform it before exit.
            close(fd)
            DistributedNotificationCenter.default().post(name: notificationName, object: nil)
            return false
        }
        lockFD = fd
        observer = DistributedNotificationCenter.default().addObserver(
            forName: notificationName, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in onReopen() }
        }
        return true
    }

    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        if lockFD >= 0 { close(lockFD) }
    }
}
