import Foundation

/// Immutable formal-release identity advertised by both public update mirrors.
///
/// GitHub and Gitee publish the exact same JSON document. The document may be
/// fetched from either host, but the ordered download list always keeps GitHub
/// first and Gitee second.
struct UpdateManifest: Decodable, Equatable, Sendable {
    enum Source: String, CaseIterable, Decodable, Sendable {
        case github
        case gitee

        var expectedHost: String {
            switch self {
            case .github: return "github.com"
            case .gitee: return "gitee.com"
            }
        }
    }

    struct Download: Decodable, Equatable, Sendable {
        let source: Source
        let url: URL
    }

    struct Artifact: Decodable, Equatable, Sendable {
        let file: String
        let sha256: String
        let downloads: [Download]
    }

    enum ValidationError: Error, Equatable, Sendable {
        case unsupportedSchema
        case unexpectedReleaseIdentity
        case invalidVersion
        case invalidBuild
        case invalidCommit
        case invalidArtifact
        case invalidDownloadSources
        case insecureURL
    }

    static let expectedBundleIdentifier = "com.aulyc.aulycshot"
    static let expectedTeamIdentifier = "M9M7M2ARFD"
    static let expectedMinimumSystemVersion = "14.0"
    private static let schemaV1 = "urn:codex-engineering-standards:dual-mirror-latest:1"
    private static let schemaV2 = "urn:codex-engineering-standards:dual-mirror-latest:2"
    private static let releaseRepository = "aulycShot"

    let schema: String
    let schemaVersion: Int
    let policy: String
    let releaseProfile: String
    let releaseChannel: String
    let version: String
    let buildNumber: Int
    let tag: String
    let commit: String
    let architecture: String
    let bundleIdentifier: String
    let pluginIdentifier: String?
    let teamIdentifier: String?
    let minimumSystemVersion: String?
    let releasePageURL: URL
    let artifact: Artifact
    let provenance: Artifact

    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case schemaVersion
        case policy
        case releaseProfile
        case releaseChannel
        case version
        case buildNumber
        case tag
        case commit
        case architecture
        case bundleIdentifier
        case pluginIdentifier
        case teamIdentifier
        case minimumSystemVersion
        case releasePageURL
        case artifact
        case provenance
    }

    static func decodeValidated(from data: Data) throws -> UpdateManifest {
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
        try manifest.validate()
        return manifest
    }

    func validate() throws {
        switch schemaVersion {
        case 1:
            guard schema == Self.schemaV1 else {
                throw ValidationError.unsupportedSchema
            }
        case 2:
            guard schema == Self.schemaV2 else {
                throw ValidationError.unsupportedSchema
            }
            guard teamIdentifier == Self.expectedTeamIdentifier,
                  minimumSystemVersion == Self.expectedMinimumSystemVersion
            else {
                throw ValidationError.unexpectedReleaseIdentity
            }
        default:
            throw ValidationError.unsupportedSchema
        }
        guard policy == "aulyc-dual-mirror-v1",
              releaseProfile == "macos-arm64-app",
              releaseChannel == "formal",
              architecture == "arm64",
              bundleIdentifier == Self.expectedBundleIdentifier,
              pluginIdentifier == nil,
              teamIdentifier == nil || teamIdentifier == Self.expectedTeamIdentifier,
              minimumSystemVersion == nil
                || minimumSystemVersion == Self.expectedMinimumSystemVersion,
              tag == version
        else {
            throw ValidationError.unexpectedReleaseIdentity
        }
        guard Self.isStableVersion(version) else {
            throw ValidationError.invalidVersion
        }
        guard buildNumber > 0 else {
            throw ValidationError.invalidBuild
        }
        guard commit.range(
            of: #"^[0-9a-f]{40}$"#,
            options: .regularExpression
        ) != nil else {
            throw ValidationError.invalidCommit
        }
        guard artifact.file.hasSuffix(".dmg"),
              provenance.file.hasSuffix(".release-provenance.json"),
              Self.isSHA256(artifact.sha256),
              Self.isSHA256(provenance.sha256)
        else {
            throw ValidationError.invalidArtifact
        }

        guard isSecureReleasePage(releasePageURL) else {
            throw ValidationError.insecureURL
        }
        try validateReleaseDownloads(artifact)
        if schemaVersion == 1 {
            try validateReleaseDownloads(provenance)
        } else {
            try validateUpdateFeedDownloads(provenance)
        }
    }

    var orderedDownloadURLs: [URL] {
        artifact.downloads.map(\.url)
    }

    var orderedProvenanceURLs: [URL] {
        provenance.downloads.map(\.url)
    }

    private static func isStableVersion(_ value: String) -> Bool {
        value.range(
            of: #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.range(
            of: #"^[0-9a-f]{64}$"#,
            options: .regularExpression
        ) != nil
    }

    private func isSecureReleasePage(_ url: URL) -> Bool {
        guard url.scheme == "https",
              url.host?.lowercased() == "github.com",
              url.query == nil,
              url.fragment == nil
        else {
            return false
        }
        return url.path == "/aulyc/\(Self.releaseRepository)/releases/tag/\(tag)"
    }

    private static func isExpectedDownloadURL(
        _ url: URL,
        tag: String,
        artifactFile: String
    ) -> Bool {
        guard url.query == nil, url.fragment == nil else { return false }
        return url.path
            == "/aulyc/\(releaseRepository)/releases/download/\(tag)/\(artifactFile)"
    }

    private func validateReleaseDownloads(_ downloadable: Artifact) throws {
        guard downloadable.downloads.map(\.source) == Source.allCases else {
            throw ValidationError.invalidDownloadSources
        }
        for download in downloadable.downloads {
            guard download.url.scheme == "https",
                  download.url.host?.lowercased() == download.source.expectedHost,
                  Self.isExpectedDownloadURL(
                    download.url,
                    tag: tag,
                    artifactFile: downloadable.file
                  )
            else {
                throw ValidationError.insecureURL
            }
        }
    }

    private func validateUpdateFeedDownloads(_ downloadable: Artifact) throws {
        guard downloadable.downloads.map(\.source) == Source.allCases else {
            throw ValidationError.invalidDownloadSources
        }
        for download in downloadable.downloads {
            let expectedHost: String
            let expectedPath: String
            switch download.source {
            case .github:
                expectedHost = "raw.githubusercontent.com"
                expectedPath = "/aulyc/\(Self.releaseRepository)/release-channel/updates/\(tag)/\(downloadable.file)"
            case .gitee:
                expectedHost = "gitee.com"
                expectedPath = "/aulyc/\(Self.releaseRepository)/raw/main/updates/\(tag)/\(downloadable.file)"
            }
            guard download.url.scheme == "https",
                  download.url.host?.lowercased() == expectedHost,
                  download.url.path == expectedPath,
                  download.url.query == nil,
                  download.url.fragment == nil
            else {
                throw ValidationError.insecureURL
            }
        }
    }
}

/// Loads the same update manifest from the ordered GitHub and Gitee mirrors.
///
/// A transport error, non-200 response, or invalid document advances to the
/// next mirror. A valid response is authoritative even when it reports that
/// the running app is already current.
final class UpdateManifestLoader: Sendable {
    struct LoadedManifest: Sendable {
        let manifest: UpdateManifest
        let sourceURL: URL
    }

    static let defaultURLs = [
        URL(string: "https://raw.githubusercontent.com/aulyc/aulycShot/release-channel/latest.json")!,
        URL(string: "https://gitee.com/aulyc/aulycShot/raw/main/latest.json")!,
    ]

    private let session: URLSession
    private let manifestURLs: [URL]
    private let userAgent: @Sendable () -> String

    init(
        session: URLSession = .shared,
        manifestURLs: [URL] = UpdateManifestLoader.defaultURLs,
        userAgent: @escaping @Sendable () -> String
    ) {
        self.session = session
        self.manifestURLs = manifestURLs
        self.userAgent = userAgent
    }

    func load(completion: @escaping @Sendable (Result<LoadedManifest, Error>) -> Void) {
        load(at: 0, lastError: URLError(.cannotFindHost), completion: completion)
    }

    private func load(
        at index: Int,
        lastError: Error,
        completion: @escaping @Sendable (Result<LoadedManifest, Error>) -> Void
    ) {
        guard manifestURLs.indices.contains(index) else {
            completion(.failure(lastError))
            return
        }

        let url = manifestURLs[index]
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent(), forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            do {
                if let error {
                    throw error
                }
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let data
                else {
                    throw URLError(.badServerResponse)
                }
                let manifest = try UpdateManifest.decodeValidated(from: data)
                completion(.success(LoadedManifest(manifest: manifest, sourceURL: url)))
            } catch {
                self.load(at: index + 1, lastError: error, completion: completion)
            }
        }.resume()
    }
}
