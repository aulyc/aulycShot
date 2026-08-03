import Foundation
import XCTest
@testable import aulycShot

final class UpdateManifestTests: XCTestCase {
    func testCentralManifestKeepsLegacyMacIdentityFields() throws {
        let data = manifestData()
        let current = try UpdateManifest.decodeValidated(from: data)
        let legacy = try JSONDecoder().decode(LegacyMacUpdateManifest.self, from: data)

        XCTAssertEqual(current.teamIdentifier, UpdateManifest.expectedTeamIdentifier)
        XCTAssertEqual(
            current.minimumSystemVersion,
            UpdateManifest.expectedMinimumSystemVersion
        )
        XCTAssertEqual(legacy.teamIdentifier, UpdateManifest.expectedTeamIdentifier)
        XCTAssertEqual(
            legacy.minimumSystemVersion,
            UpdateManifest.expectedMinimumSystemVersion
        )
        XCTAssertEqual(legacy.version, current.version)
        XCTAssertEqual(legacy.artifact.downloads.map(\.source), [.github, .gitee])
    }

    func testManifestRejectsWrongLegacyMacIdentity() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(
                from: manifestData(teamIdentifier: "OTHERTEAM")
            )
        ) { error in
            XCTAssertEqual(
                error as? UpdateManifest.ValidationError,
                .unexpectedReleaseIdentity
            )
        }
    }

    func testValidCentralManifestKeepsGitHubBeforeGitee() throws {
        let manifest = try UpdateManifest.decodeValidated(from: manifestData())

        XCTAssertEqual(manifest.version, "1.7.4")
        XCTAssertEqual(
            manifest.orderedDownloadURLs.map(\.host),
            ["github.com", "gitee.com"]
        )
        XCTAssertEqual(
            manifest.orderedProvenanceURLs.map(\.host),
            ["github.com", "gitee.com"]
        )
    }

    func testManifestRejectsReversedDownloadOrder() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(
                from: manifestData(downloadOrder: [.gitee, .github])
            )
        ) { error in
            XCTAssertEqual(
                error as? UpdateManifest.ValidationError,
                .invalidDownloadSources
            )
        }
    }

    func testManifestRejectsHTTPDownload() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(
                from: manifestData(githubURL: "http://github.com/aulyc/aulycShot-releases/releases/download/1.7.4/aulycShot-1.7.4-build.502-arm64.dmg")
            )
        ) { error in
            XCTAssertEqual(error as? UpdateManifest.ValidationError, .insecureURL)
        }
    }

    func testManifestRejectsMissingGiteeMirror() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(from: manifestData(downloadOrder: [.github]))
        ) { error in
            XCTAssertEqual(
                error as? UpdateManifest.ValidationError,
                .invalidDownloadSources
            )
        }
    }

    func testManifestRejectsWrongPolicy() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(
                from: manifestData(policy: "another-policy")
            )
        ) { error in
            XCTAssertEqual(
                error as? UpdateManifest.ValidationError,
                .unexpectedReleaseIdentity
            )
        }
    }

    func testManifestRejectsDownloadFromAnotherGitHubRepository() {
        XCTAssertThrowsError(
            try UpdateManifest.decodeValidated(
                from: manifestData(
                    githubURL: "https://github.com/other/project/releases/download/1.7.4/aulycShot-1.7.4-build.502-arm64.dmg"
                )
            )
        ) { error in
            XCTAssertEqual(error as? UpdateManifest.ValidationError, .insecureURL)
        }
    }

    func testLoaderFallsBackFromGitHubServerFailureToGitee() {
        let github = URL(string: "https://github.example/latest.json")!
        let gitee = URL(string: "https://gitee.example/latest.json")!
        var requestedURLs: [URL] = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateManifestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        UpdateManifestURLProtocol.handler = { request in
            requestedURLs.append(try XCTUnwrap(request.url))
            if request.url == github {
                return (503, Data(), nil)
            }
            return (200, self.manifestData(), nil)
        }
        let loader = UpdateManifestLoader(
            session: session,
            manifestURLs: [github, gitee],
            userAgent: { "aulycShot/tests" }
        )
        let finished = expectation(description: "manifest fallback completes")

        loader.load { result in
            switch result {
            case .success(let loaded):
                XCTAssertEqual(loaded.sourceURL, gitee)
                XCTAssertEqual(loaded.manifest.version, "1.7.4")
            case .failure(let error):
                XCTFail("unexpected failure: \(error)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 2)
        XCTAssertEqual(requestedURLs, [github, gitee])
    }

    func testLoaderDoesNotContactGiteeAfterValidGitHubManifest() {
        let github = URL(string: "https://github.example/latest.json")!
        let gitee = URL(string: "https://gitee.example/latest.json")!
        var requestedURLs: [URL] = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateManifestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        UpdateManifestURLProtocol.handler = { request in
            requestedURLs.append(try XCTUnwrap(request.url))
            return (200, self.manifestData(), nil)
        }
        let loader = UpdateManifestLoader(
            session: session,
            manifestURLs: [github, gitee],
            userAgent: { "aulycShot/tests" }
        )
        let finished = expectation(description: "primary manifest completes")

        loader.load { result in
            if case .failure(let error) = result {
                XCTFail("unexpected failure: \(error)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 2)
        XCTAssertEqual(requestedURLs, [github])
    }

    func testInstallerComputesStreamingSHA256() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-update-hash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("formal artifact".utf8).write(to: file)

        XCTAssertEqual(
            try UpdateInstaller.sha256(of: file),
            "ea14e9899373ed6766354c7137c01f00de19810f345a1f124d3685bfc7a546b3"
        )
    }

    func testInstallerPreservesURLSessionDownloadBeforeDelegateReturns() throws {
        let payload = Data("formal provenance".utf8)
        let hashInput = FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-update-hash-\(UUID().uuidString)")
        try payload.write(to: hashInput)
        let expectedSHA256 = try UpdateInstaller.sha256(of: hashInput)
        try FileManager.default.removeItem(at: hashInput)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateManifestURLProtocol.self]
        let installer = UpdateInstaller(sessionConfiguration: configuration)
        UpdateManifestURLProtocol.handler = { _ in
            (200, payload, nil)
        }
        let finished = expectation(description: "download is preserved")

        installer.downloadProvenance(
            from: [URL(string: "https://download.example/provenance.json")!],
            expectedSHA256: expectedSHA256
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("unexpected failure: \(error)")
            case .success(let url):
                defer { try? FileManager.default.removeItem(at: url) }
                XCTAssertEqual(try? Data(contentsOf: url), payload)
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 2)
    }

    func testInstallerRequiresProvenanceToBindSourceAndArtifact() throws {
        let manifest = try UpdateManifest.decodeValidated(from: manifestData())
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-update-provenance-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var value: [String: Any] = [
            "releaseProfile": manifest.releaseProfile,
            "releaseChannel": manifest.releaseChannel,
            "version": manifest.version,
            "buildNumber": manifest.buildNumber,
            "tag": manifest.tag,
            "commit": manifest.commit,
            "dirty": false,
            "bundleIdentifier": manifest.bundleIdentifier,
            "architecture": manifest.architecture,
            "teamIdentifier": UpdateManifest.expectedTeamIdentifier,
            "minimumSystemVersion": UpdateManifest.expectedMinimumSystemVersion,
            "sourceRepository": "aulyc/aulycShot",
            "sourceRemoteCommit": manifest.commit,
            "sourceRemoteTagCommit": manifest.commit,
            "sourceRemoteVerifiedAt": "2026-07-30T00:00:00Z",
            "artifacts": [
                [
                    "file": manifest.artifact.file,
                    "sha256": manifest.artifact.sha256,
                ],
            ],
        ]
        try JSONSerialization.data(withJSONObject: value).write(to: file)
        XCTAssertNoThrow(
            try UpdateInstaller.verifyProvenance(at: file, manifest: manifest)
        )

        value["sourceRemoteTagCommit"] = String(repeating: "d", count: 40)
        try JSONSerialization.data(withJSONObject: value).write(to: file)
        XCTAssertThrowsError(
            try UpdateInstaller.verifyProvenance(at: file, manifest: manifest)
        ) { error in
            XCTAssertEqual(
                error as? UpdateInstaller.InstallError,
                .invalidProvenance
            )
        }
    }

    override func tearDown() {
        UpdateManifestURLProtocol.handler = nil
        super.tearDown()
    }

    private func manifestData(
        downloadOrder: [UpdateManifest.Source] = [.github, .gitee],
        githubURL: String = "https://github.com/aulyc/aulycShot-releases/releases/download/1.7.4/aulycShot-1.7.4-build.502-arm64.dmg",
        policy: String = "aulyc-dual-mirror-v1",
        teamIdentifier: String = UpdateManifest.expectedTeamIdentifier,
        minimumSystemVersion: String = UpdateManifest.expectedMinimumSystemVersion
    ) -> Data {
        let giteeURL = (
            "https://gitee.com/aulyc/aulycShot-releases/releases/download/"
            + "1.7.4/aulycShot-1.7.4-build.502-arm64.dmg"
        )
        let downloads = downloadOrder.map { source -> [String: String] in
            [
                "source": source.rawValue,
                "url": source == .github ? githubURL : giteeURL,
            ]
        }
        let provenanceFile = "aulycShot-1.7.4-build.502-arm64.release-provenance.json"
        let provenanceDownloads = downloadOrder.map { source -> [String: String] in
            let host = source == .github ? "github.com" : "gitee.com"
            return [
                "source": source.rawValue,
                "url": "https://\(host)/aulyc/aulycShot-releases/releases/download/1.7.4/\(provenanceFile)",
            ]
        }
        let value: [String: Any] = [
            "$schema": "urn:codex-engineering-standards:dual-mirror-latest:1",
            "schemaVersion": 1,
            "policy": policy,
            "releaseProfile": "macos-arm64-app",
            "releaseChannel": "formal",
            "version": "1.7.4",
            "buildNumber": 502,
            "tag": "1.7.4",
            "commit": String(repeating: "a", count: 40),
            "architecture": "arm64",
            "bundleIdentifier": UpdateManifest.expectedBundleIdentifier,
            "pluginIdentifier": NSNull(),
            "teamIdentifier": teamIdentifier,
            "minimumSystemVersion": minimumSystemVersion,
            "releasePageURL": "https://github.com/aulyc/aulycShot-releases/releases/tag/1.7.4",
            "artifact": [
                "file": "aulycShot-1.7.4-build.502-arm64.dmg",
                "sha256": String(repeating: "b", count: 64),
                "downloads": downloads,
            ],
            "provenance": [
                "file": provenanceFile,
                "sha256": String(repeating: "c", count: 64),
                "downloads": provenanceDownloads,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}

private struct LegacyMacUpdateManifest: Decodable {
    enum Source: String, Decodable {
        case github
        case gitee
    }

    struct Download: Decodable {
        let source: Source
        let url: URL
    }

    struct Artifact: Decodable {
        let file: String
        let sha256: String
        let downloads: [Download]
    }

    let schemaVersion: Int
    let releaseProfile: String
    let releaseChannel: String
    let version: String
    let buildNumber: Int
    let tag: String
    let commit: String
    let architecture: String
    let bundleIdentifier: String
    let teamIdentifier: String
    let minimumSystemVersion: String
    let releasePageURL: URL
    let artifact: Artifact
}

private final class UpdateManifestURLProtocol: URLProtocol {
    private static let handlerStore = UpdateManifestHandlerStore()
    static var handler: ((URLRequest) throws -> (status: Int, data: Data, error: Error?))? {
        get { handlerStore.handler }
        set { handlerStore.handler = newValue }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let result = try handler(request)
            if let error = result.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: result.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// URLProtocol callbacks and test setup share the handler only through `lock`.
private final class UpdateManifestHandlerStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedHandler: ((URLRequest) throws -> (status: Int, data: Data, error: Error?))?

    var handler: ((URLRequest) throws -> (status: Int, data: Data, error: Error?))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedHandler
        }
        set {
            lock.lock()
            storedHandler = newValue
            lock.unlock()
        }
    }
}
