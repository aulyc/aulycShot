import Foundation
import CryptoKit

/// Downloads a formal aulycShot DMG and installs it in place of the running app.
///
/// The running `.app` bundle can't overwrite itself while it's open, so the
/// final swap is handed to a detached `/bin/bash` helper: it waits for this
/// process to exit, replaces the bundle, and relaunches. The caller must
/// terminate the app immediately after `install` returns.
final class UpdateInstaller: NSObject {
    static let shared = UpdateInstaller()

    enum InstallError: Error {
        case download
        case checksumMismatch
        case invalidManifest
        case mountFailed
        case bundleNotFound
        case identityMismatch
        case signatureInvalid
        case notWritable
    }

    private var session: URLSession?
    private var progressHandler: ((Double) -> Void)?
    private var finishHandler: ((Result<URL, Error>) -> Void)?
    private var downloadURLs: [URL] = []
    private var downloadIndex = 0
    private var expectedSHA256 = ""
    private var activeTaskIdentifier: Int?
    private var handledTaskIdentifiers = Set<Int>()
    private var delivered = false

    // MARK: - Download

    /// Downloads the formal DMG from ordered mirrors. A transport, HTTP, or
    /// checksum failure advances to the next URL. Both handlers fire on the
    /// main thread.
    func downloadDMG(
        from urls: [URL],
        expectedSHA256: String,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !urls.isEmpty else {
            DispatchQueue.main.async { completion(.failure(InstallError.download)) }
            return
        }

        downloadURLs = urls
        downloadIndex = 0
        self.expectedSHA256 = expectedSHA256
        progressHandler = progress
        finishHandler = completion
        activeTaskIdentifier = nil
        handledTaskIdentifiers.removeAll()
        delivered = false

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        startCurrentDownload()
    }

    private func startCurrentDownload() {
        guard downloadURLs.indices.contains(downloadIndex), let session else {
            deliver(.failure(InstallError.download))
            return
        }
        DispatchQueue.main.async { self.progressHandler?(0) }
        var request = URLRequest(url: downloadURLs[downloadIndex])
        request.setValue("aulycShot", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        activeTaskIdentifier = task.taskIdentifier
        task.resume()
    }

    private func retryDownload(after error: Error) {
        guard !delivered else { return }
        downloadIndex += 1
        guard downloadURLs.indices.contains(downloadIndex) else {
            deliver(.failure(error))
            return
        }
        startCurrentDownload()
    }

    private func deliver(_ result: Result<URL, Error>) {
        guard !delivered else { return }
        delivered = true
        let handler = finishHandler
        finishHandler = nil
        progressHandler = nil
        downloadURLs = []
        activeTaskIdentifier = nil
        session?.finishTasksAndInvalidate()
        session = nil
        DispatchQueue.main.async { handler?(result) }
    }

    // MARK: - Install

    /// Verifies the DMG, mounts and copies its App, validates the immutable
    /// release identity and Developer ID signature, then spawns the detached
    /// helper that swaps the bundle and relaunches.
    ///
    /// `phase` is invoked synchronously on this thread as each step begins, so
    /// the UI can show "verifying / extracting / installing" in turn.
    static func install(
        dmgAt dmgURL: URL,
        manifest: UpdateManifest,
        phase: (InstallPhase) -> Void
    ) throws {
        do {
            try manifest.validate()
        } catch {
            throw InstallError.invalidManifest
        }

        let fm = FileManager.default
        var scratchDir: URL?
        var mountPoint: URL?
        var mounted = false
        var handedOff = false
        defer {
            if mounted, let mountPoint {
                try? runProcess(
                    "/usr/bin/hdiutil",
                    ["detach", mountPoint.path],
                    throwing: .mountFailed
                )
            }
            try? fm.removeItem(at: dmgURL)
            if let dir = scratchDir, !handedOff { try? fm.removeItem(at: dir) }
        }

        // 1. The checksum is mandatory and binds either mirror to the same
        // exact-tag formal artifact.
        phase(.verifying)
        guard try sha256(of: dmgURL) == manifest.artifact.sha256 else {
            throw InstallError.checksumMismatch
        }

        // 2. Mount the notarized DMG read-only and copy the App to a private
        // scratch directory before detaching the image.
        phase(.unzipping)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("aulycShot-update-\(UUID().uuidString)", isDirectory: true)
        scratchDir = workDir
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        let mountedAt = workDir.appendingPathComponent("mount", isDirectory: true)
        mountPoint = mountedAt
        try fm.createDirectory(at: mountedAt, withIntermediateDirectories: true)
        try runProcess(
            "/usr/bin/hdiutil",
            ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountedAt.path],
            throwing: .mountFailed
        )
        mounted = true

        let mountedApp = mountedAt.appendingPathComponent("aulycShot.app", isDirectory: true)
        guard fm.fileExists(atPath: mountedApp.path) else {
            throw InstallError.bundleNotFound
        }
        let replacementDir = workDir.appendingPathComponent("replacement", isDirectory: true)
        try fm.createDirectory(at: replacementDir, withIntermediateDirectories: true)
        let newApp = replacementDir.appendingPathComponent("aulycShot.app", isDirectory: true)
        try runProcess(
            "/usr/bin/ditto",
            [mountedApp.path, newApp.path],
            throwing: .bundleNotFound
        )
        try runProcess(
            "/usr/bin/hdiutil",
            ["detach", mountedAt.path],
            throwing: .mountFailed
        )
        mounted = false

        guard fm.fileExists(
            atPath: newApp.appendingPathComponent("Contents/MacOS/aulycShot").path
        ) else {
            throw InstallError.bundleNotFound
        }

        // 3. Verify product metadata, embedded exact-tag identity, architecture,
        // Developer ID team, Hardened Runtime, nested code, and Gatekeeper.
        try verifyApplication(at: newApp, manifest: manifest)

        // 4. Confirm we can replace the running bundle before handing off.
        phase(.installing)
        let oldApp = Bundle.main.bundleURL
        let parent = oldApp.deletingLastPathComponent()
        guard fm.isWritableFile(atPath: parent.path) else { throw InstallError.notWritable }

        // 5. Hand the swap off to a detached helper and let the caller quit.
        spawnSwapHelper(newApp: newApp.path, oldApp: oldApp.path)
        handedOff = true
    }

    /// Deletes leftover update artifacts (`aulycShot-update-*` DMGs and scratch
    /// dirs) from the temp directory. The current run cleans up after itself,
    /// but a crash or force-quit between download and swap can strand files;
    /// calling this before each update keeps them from accumulating.
    static func cleanStaleArtifacts() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: fm.temporaryDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in entries where url.lastPathComponent.hasPrefix("aulycShot-update-") {
            try? fm.removeItem(at: url)
        }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while true {
            guard let data = try handle.read(upToCount: 1024 * 1024),
                  !data.isEmpty
            else {
                break
            }
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func verifyApplication(
        at app: URL,
        manifest: UpdateManifest
    ) throws {
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let info = value as? [String: Any],
              info["CFBundleIdentifier"] as? String == manifest.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == manifest.version,
              String(describing: info["CFBundleVersion"] ?? "") == String(manifest.buildNumber),
              info["LSMinimumSystemVersion"] as? String == manifest.minimumSystemVersion,
              info["AulycShotGitCommit"] as? String == manifest.commit,
              info["AulycShotReleaseChannel"] as? String == "formal",
              info["AulycShotReleaseTag"] as? String == manifest.tag,
              info["AulycShotBuildDirty"] as? Bool == false
        else {
            throw InstallError.identityMismatch
        }

        let executable = app.appendingPathComponent("Contents/MacOS/aulycShot")
        let extensionBundle = app.appendingPathComponent(
            "Contents/PlugIns/AulycShotShareExtension.appex"
        )
        let extensionExecutable = extensionBundle.appendingPathComponent(
            "Contents/MacOS/AulycShotShareExtension"
        )
        guard FileManager.default.fileExists(atPath: executable.path),
              FileManager.default.fileExists(atPath: extensionExecutable.path)
        else {
            throw InstallError.bundleNotFound
        }

        try runProcess(
            "/usr/bin/codesign",
            ["--verify", "--deep", "--strict", "--verbose=2", app.path],
            throwing: .signatureInvalid
        )
        try verifySignatureDetails(at: app, expectedTeamIdentifier: manifest.teamIdentifier)
        try verifySignatureDetails(
            at: extensionBundle,
            expectedTeamIdentifier: manifest.teamIdentifier
        )

        guard try capturedOutput(
            "/usr/bin/lipo",
            ["-archs", executable.path],
            throwing: .identityMismatch
        ) == "arm64",
        try capturedOutput(
            "/usr/bin/lipo",
            ["-archs", extensionExecutable.path],
            throwing: .identityMismatch
        ) == "arm64"
        else {
            throw InstallError.identityMismatch
        }

        try runProcess(
            "/usr/sbin/spctl",
            ["-a", "-vvv", "-t", "exec", app.path],
            throwing: .signatureInvalid
        )
    }

    private static func verifySignatureDetails(
        at code: URL,
        expectedTeamIdentifier: String
    ) throws {
        let details = try capturedOutput(
            "/usr/bin/codesign",
            ["-dv", "--verbose=4", code.path],
            throwing: .signatureInvalid
        )
        guard details.contains("Authority=Developer ID Application:"),
              details.contains("TeamIdentifier=\(expectedTeamIdentifier)"),
              details.contains("(runtime)")
        else {
            throw InstallError.signatureInvalid
        }
    }

    private static func runProcess(
        _ launchPath: String,
        _ arguments: [String],
        throwing error: InstallError
    ) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = nil
        task.standardError = nil
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw error }
    }

    private static func capturedOutput(
        _ launchPath: String,
        _ arguments: [String],
        throwing error: InstallError
    ) throws -> String {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw error }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Launches a `/bin/bash` script that outlives this process: it waits for
    /// aulycShot to quit, swaps the bundle (keeping a backup it restores on
    /// failure), and reopens the app.
    private static func spawnSwapHelper(newApp: String, oldApp: String) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        NEW="$1"; OLD="$2"; PID="$3"
        # Wait (up to ~15s) for aulycShot to exit before touching its bundle.
        for _ in $(seq 1 150); do
          kill -0 "$PID" 2>/dev/null || break
          sleep 0.1
        done
        BACKUP="${OLD}.aulycShot-backup-${PID}"
        mv "$OLD" "$BACKUP" || exit 1
        if /usr/bin/ditto "$NEW" "$OLD"; then
          rm -rf "$BACKUP"
        else
          # Restore the old bundle so the user isn't left with nothing.
          rm -rf "$OLD"
          mv "$BACKUP" "$OLD"
        fi
        rm -rf "$(dirname "$NEW")"
        /usr/bin/open "$OLD"
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", script, "aulycShot-updater", newApp, oldApp, String(pid)]
        try? task.run()
    }
}

extension UpdateInstaller: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let clamped = min(max(fraction, 0), 1)
        DispatchQueue.main.async { self.progressHandler?(clamped) }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard downloadTask.taskIdentifier == activeTaskIdentifier, !delivered else { return }
        handledTaskIdentifiers.insert(downloadTask.taskIdentifier)

        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            retryDownload(after: InstallError.download)
            return
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-update-\(UUID().uuidString).dmg")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            guard try Self.sha256(of: dest) == expectedSHA256 else {
                try? FileManager.default.removeItem(at: dest)
                retryDownload(after: InstallError.checksumMismatch)
                return
            }
            deliver(.success(dest))
        } catch {
            try? FileManager.default.removeItem(at: dest)
            retryDownload(after: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard task.taskIdentifier == activeTaskIdentifier,
              !handledTaskIdentifiers.contains(task.taskIdentifier),
              !delivered
        else { return }
        handledTaskIdentifiers.insert(task.taskIdentifier)
        retryDownload(after: error ?? InstallError.download)
    }
}
