import AppKit
import Foundation

/// Outcome of an update check / install. Drives the menu bar item and the
/// About pane.
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(version: String, fraction: Double)
    case installing(version: String, phase: InstallPhase)
    case failed
    case installFailed(version: String)
}

/// Sub-steps of the in-place install, surfaced so the UI can say "verifying"
/// or "extracting" rather than one opaque "installing".
enum InstallPhase: Equatable {
    case verifying
    case unzipping
    case installing
}

extension Notification.Name {
    static let updateStateDidChange = Notification.Name("aulycShot.updateStateDidChange")
}

/// Checks the public GitHub/Gitee update mirrors for a newer formal aulycShot
/// release and, when asked, downloads and installs it in place.
///
/// Both mirrors publish the same manifest and notarized DMG. `UpdateInstaller`
/// owns download/hash/signature/install verification; this type owns the UI
/// state machine and mirror failover.
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let throttleKey = "lastUpdateCheckAt"
    private let skippedVersionKey = "skippedUpdateVersion"
    private let shortcutTriggerDayKey = "automaticUpdateCheckShortcutTriggerDay"
    private let shortcutTriggerCountKey = "automaticUpdateCheckShortcutTriggerCount"
    private let automaticCheckShortcutTriggerCount = 1
    private lazy var manifestLoader = UpdateManifestLoader {
        "aulycShot/\(self.currentVersion)"
    }

    private(set) var state: UpdateState = .idle {
        didSet {
            NotificationCenter.default.post(name: .updateStateDidChange, object: nil)
        }
    }

    /// Details of the latest release, populated by a successful check.
    private(set) var latestVersion: String?
    private(set) var latestPageURL: URL?
    private(set) var latestManifestSourceURL: URL?
    private var latestManifest: UpdateManifest?

    private init() {}

    /// Running app version, e.g. "1.1.2".
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// The version the user chose to skip, if any.
    var skippedVersion: String? {
        UserDefaults.standard.string(forKey: skippedVersionKey)
    }

    /// True while a check or install is in flight — used to reject overlapping
    /// requests.
    private var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    /// Silent automatic check tied to real usage rather than app launch. The
    /// first screenshot-shortcut trigger of each local day checks the mirrors
    /// unless a check already ran today.
    func checkFromScreenshotShortcutIfDue() {
        guard Defaults.automaticUpdateChecksEnabled else { return }

        let today = Self.dayKey(for: Date())
        let defaults = UserDefaults.standard
        var triggerCount = defaults.integer(forKey: shortcutTriggerCountKey)

        if defaults.string(forKey: shortcutTriggerDayKey) != today {
            defaults.set(today, forKey: shortcutTriggerDayKey)
            triggerCount = 0
        }

        triggerCount += 1
        defaults.set(triggerCount, forKey: shortcutTriggerCountKey)

        guard triggerCount == automaticCheckShortcutTriggerCount,
              !hasCheckedToday,
              !isBusy
        else { return }

        check(manual: false)
    }

    private var hasCheckedToday: Bool {
        guard let last = UserDefaults.standard.object(forKey: throttleKey) as? Date else {
            return false
        }
        return Calendar.autoupdatingCurrent.isDateInToday(last)
    }

    /// Performs a check. `completion` fires on the main thread with the final
    /// state. Manual checks ignore the screenshot-shortcut gate and the
    /// skipped-version preference; a background check stays silent about a
    /// skipped version.
    func check(manual: Bool, completion: ((UpdateState) -> Void)? = nil) {
        guard !isBusy else {
            completion?(state)
            return
        }
        setState(.checking)

        manifestLoader.load { [weak self] result in
            guard let self else { return }

            UserDefaults.standard.set(Date(), forKey: self.throttleKey)
            switch result {
            case .failure:
                self.finish(.failed, completion: completion)
            case .success(let loaded):
                let manifest = loaded.manifest
                guard Self.isVersion(manifest.version, newerThan: self.currentVersion) else {
                    self.latestManifest = nil
                    self.latestVersion = nil
                    self.latestPageURL = nil
                    self.latestManifestSourceURL = loaded.sourceURL
                    self.finish(.upToDate, completion: completion)
                    return
                }

                self.latestManifest = manifest
                self.latestVersion = manifest.version
                self.latestPageURL = manifest.releasePageURL
                self.latestManifestSourceURL = loaded.sourceURL

                if !manual, manifest.version == self.skippedVersion {
                    self.finish(.upToDate, completion: completion)
                } else {
                    self.finish(.available(version: manifest.version), completion: completion)
                }
            }
        }
    }

    /// Marks the latest release as skipped so future background checks ignore
    /// it, and resets the UI to the up-to-date state.
    func skipVersion() {
        guard let version = latestVersion else { return }
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
        setState(.upToDate)
    }

    /// Downloads the latest release, verifies it, installs it in place of the
    /// running app, and relaunches. `onFailure` fires on the main thread if any
    /// step fails — the running app is left untouched. On success the app
    /// terminates and the detached helper reopens the new build.
    func downloadAndInstall(onFailure: (() -> Void)? = nil) {
        let version: String
        switch state {
        case .available(let availableVersion):
            version = availableVersion
        case .failed:
            guard let knownVersion = latestVersion else { return }
            version = knownVersion
        default:
            return
        }
        guard let manifest = latestManifest, manifest.version == version else { return }

        // Clear anything an earlier interrupted update left behind so temp
        // artifacts never pile up across runs.
        UpdateInstaller.cleanStaleArtifacts()

        setState(.downloading(version: version, fraction: 0))

        let fail: () -> Void = { [weak self] in
            self?.setState(.installFailed(version: version))
            onFailure?()
        }

        UpdateInstaller.shared.downloadProvenance(
            from: manifest.orderedProvenanceURLs,
            expectedSHA256: manifest.provenance.sha256
        ) { provenanceResult in
            switch provenanceResult {
            case .failure:
                fail()
            case .success(let provenancePath):
                var lastPercent = -1
                UpdateInstaller.shared.downloadDMG(
                    from: manifest.orderedDownloadURLs,
                    expectedSHA256: manifest.artifact.sha256,
                    progress: { fraction in
                        // Throttle to whole-percent steps so the menu/About
                        // pane does not rebuild on every byte.
                        let percent = Int(fraction * 100)
                        guard percent != lastPercent else { return }
                        lastPercent = percent
                        self.setState(
                            .downloading(version: version, fraction: fraction)
                        )
                    },
                    completion: { result in
                        switch result {
                        case .failure:
                            try? FileManager.default.removeItem(at: provenancePath)
                            fail()
                        case .success(let dmgPath):
                            self.setState(
                                .installing(version: version, phase: .verifying)
                            )
                            DispatchQueue.global(qos: .userInitiated).async {
                                do {
                                    try UpdateInstaller.install(
                                        dmgAt: dmgPath,
                                        provenanceAt: provenancePath,
                                        manifest: manifest,
                                        phase: { phase in
                                            self.setState(
                                                .installing(
                                                    version: version,
                                                    phase: phase
                                                )
                                            )
                                        }
                                    )
                                    DispatchQueue.main.async { NSApp.terminate(nil) }
                                } catch {
                                    DispatchQueue.main.async { fail() }
                                }
                            }
                        }
                    }
                )
            }
        }
    }

    private func finish(_ newState: UpdateState, completion: ((UpdateState) -> Void)?) {
        DispatchQueue.main.async {
            self.state = newState
            completion?(newState)
        }
    }

    private func setState(_ newState: UpdateState) {
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { self.state = newState }
        }
    }

    /// Strips a leading `release-v` / `v` from a tag — aulycShot tags releases as
    /// `release-v1.1.2`, so "release-v1.1.2" becomes "1.1.2".
    static func normalizeVersion(_ raw: String) -> String {
        var v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("release-v") {
            v.removeFirst("release-v".count)
        } else if v.hasPrefix("release-") {
            v.removeFirst("release-".count)
        }
        if v.hasPrefix("v") || v.hasPrefix("V") {
            v.removeFirst()
        }
        return v
    }

    /// Component-wise numeric comparison: "1.2.0" is newer than "1.1.9".
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let a = components(lhs)
        let b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
}
