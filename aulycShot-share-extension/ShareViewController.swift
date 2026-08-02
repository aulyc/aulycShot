import AppKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: NSViewController {
    private static let handoffNotificationName = Notification.Name("com.aulyc.aulycshot.share-handoff")

    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "Opening aulycShot")
    private var didStartProcessing = false

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 112))

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.startAnimation(nil)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(progressIndicator)
        rootView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),

            statusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24)
        ])

        view = rootView
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard !didStartProcessing else { return }
        didStartProcessing = true
        processFirstSharedImage()
    }

    private func processFirstSharedImage() {
        guard let candidate = firstImageCandidate() else {
            fail(with: "No image found")
            return
        }

        if candidate.provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let controller = WeakShareViewController(self)
            candidate.provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let payload = ShareItemProviderPayload(item)
                Task { @MainActor in
                    guard let self = controller.value else { return }

                    if let sourceURL = self.fileURL(from: payload.value),
                       let handoffURL = self.copyImageFileToHandoffDirectory(
                           sourceURL,
                           typeIdentifier: candidate.imageTypeIdentifier
                       ) {
                        self.openContainingApp(with: handoffURL)
                        return
                    }

                    self.loadImagePayload(
                        from: candidate.provider,
                        typeIdentifier: candidate.imageTypeIdentifier
                    )
                }
            }
            return
        }

        loadImagePayload(from: candidate.provider, typeIdentifier: candidate.imageTypeIdentifier)
    }

    private func loadImagePayload(from provider: NSItemProvider, typeIdentifier: String?) {
        guard let typeIdentifier else {
            fail(with: "Unable to read image")
            return
        }

        let controller = WeakShareViewController(self)
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            let payload = ShareItemProviderPayload(item)
            Task { @MainActor in
                guard let self = controller.value else { return }

                guard let handoffURL = self.writeImagePayload(payload.value, typeIdentifier: typeIdentifier) else {
                    self.fail(with: "Unable to read image")
                    return
                }

                self.openContainingApp(with: handoffURL)
            }
        }
    }

    private func openContainingApp(with fileURL: URL) {
        openHandoffURL(for: fileURL) { [weak self] success in
            guard let self else { return }
            if success {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            self.launchContainingApplication { [weak self] success in
                guard let self else { return }
                if success {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard let self else { return }
                        self.postHandoffNotification(for: fileURL)
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                } else {
                    self.fail(with: "Unable to open aulycShot")
                }
            }
        }
    }

    private func launchContainingApplication(
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        guard let appURL = Self.containingApplicationURL() else {
            completion(false)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                NSLog("aulycShot share extension: failed to launch containing app: \(error)")
            }

            Task { @MainActor in
                completion(error == nil)
            }
        }
    }

    private func postHandoffNotification(for fileURL: URL) {
        DistributedNotificationCenter.default().postNotificationName(
            Self.handoffNotificationName,
            object: nil,
            userInfo: ["file": fileURL.path],
            deliverImmediately: true
        )
    }

    private func openHandoffURL(
        for fileURL: URL,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        guard let url = Self.handoffURL(for: fileURL) else {
            completion(false)
            return
        }

        if NSWorkspace.shared.open(url) {
            completion(true)
            return
        }

        guard let extensionContext else {
            completion(false)
            return
        }

        extensionContext.open(url) { success in
            Task { @MainActor in
                if success {
                    completion(true)
                } else {
                    NSLog("aulycShot share extension: extension context refused handoff URL")
                    completion(false)
                }
            }
        }
    }

    private func firstImageCandidate() -> ImageCandidate? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []

        for item in items {
            for provider in item.attachments ?? [] {
                if let imageTypeIdentifier = Self.firstImageTypeIdentifier(in: provider) {
                    return ImageCandidate(provider: provider, imageTypeIdentifier: imageTypeIdentifier)
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    return ImageCandidate(provider: provider, imageTypeIdentifier: nil)
                }
            }
        }

        return nil
    }

    private func writeImagePayload(_ item: NSSecureCoding?, typeIdentifier: String) -> URL? {
        if let url = fileURL(from: item) {
            return copyImageFileToHandoffDirectory(url, typeIdentifier: typeIdentifier)
        }

        if let data = item as? Data {
            return writeImageData(data, typeIdentifier: typeIdentifier)
        }

        if let image = item as? NSImage {
            return writeImage(image)
        }

        return nil
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url.isFileURL ? url : nil
        }

        if let url = item as? NSURL {
            let swiftURL = url as URL
            return swiftURL.isFileURL ? swiftURL : nil
        }

        return nil
    }

    private func copyImageFileToHandoffDirectory(_ sourceURL: URL, typeIdentifier: String?) -> URL? {
        guard sourceURL.isFileURL else { return nil }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let image = NSImage(contentsOf: sourceURL),
              image.size.width > 0,
              image.size.height > 0
        else {
            return nil
        }

        let destinationURL = nextHandoffURL(
            filename: sourceURL.lastPathComponent.isEmpty ? "SharedImage" : sourceURL.lastPathComponent,
            typeIdentifier: typeIdentifier
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            NSLog("aulycShot share extension: failed to copy image file: \(error)")
            return nil
        }
    }

    private func writeImage(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        return writeImageData(pngData, typeIdentifier: UTType.png.identifier)
    }

    private func writeImageData(_ data: Data, typeIdentifier: String) -> URL? {
        guard let image = NSImage(data: data),
              image.size.width > 0,
              image.size.height > 0
        else {
            return nil
        }

        let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "png"
        let destinationURL = handoffDirectory()
            .appendingPathComponent("\(UUID().uuidString).\(fileExtension)", isDirectory: false)

        do {
            try data.write(to: destinationURL, options: .atomic)
            return destinationURL
        } catch {
            NSLog("aulycShot share extension: failed to write image data: \(error)")
            return nil
        }
    }

    private func nextHandoffURL(filename: String, typeIdentifier: String?) -> URL {
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let originalExtension = URL(fileURLWithPath: filename).pathExtension
        let inferredExtension = typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension }
        let fileExtension = originalExtension.isEmpty ? (inferredExtension ?? "png") : originalExtension
        let safeBaseName = baseName.isEmpty ? "SharedImage" : baseName

        return handoffDirectory()
            .appendingPathComponent("\(UUID().uuidString)-\(safeBaseName).\(fileExtension)", isDirectory: false)
    }

    private func handoffDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-share-handoff", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        removeStaleFiles(in: directory)

        return directory
    }

    private func removeStaleFiles(in directory: URL) {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)

        for fileURL in fileURLs {
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            if let date = values?.contentModificationDate, date < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func fail(with message: String) {
        progressIndicator.stopAnimation(nil)
        statusLabel.stringValue = message

        let error = NSError(
            domain: "com.aulyc.aulycshot.share-extension",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private static func firstImageTypeIdentifier(in provider: NSItemProvider) -> String? {
        for identifier in provider.registeredTypeIdentifiers {
            if UTType(identifier)?.conforms(to: .image) == true {
                return identifier
            }
        }

        return provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ? UTType.image.identifier : nil
    }

    private static func handoffURL(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "aulycshot"
        components.host = "edit"
        components.queryItems = [
            URLQueryItem(name: "file", value: fileURL.path)
        ]
        return components.url
    }

    private static func containingApplicationURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "appex" else { return nil }

        return bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct ImageCandidate: @unchecked Sendable {
    let provider: NSItemProvider
    let imageTypeIdentifier: String?
}

/// `NSItemProvider` invokes its load callback on an unspecified queue and hands
/// it an Objective-C payload whose concrete type is not statically Sendable.
/// The payload is never inspected until the task has entered the main actor.
private struct ShareItemProviderPayload: @unchecked Sendable {
    let value: NSSecureCoding?

    init(_ value: NSSecureCoding?) {
        self.value = value
    }
}

/// The provider callback must not capture the main-actor controller directly.
/// This weak bridge is only dereferenced after entering the main actor.
private final class WeakShareViewController: @unchecked Sendable {
    weak var value: ShareViewController?

    init(_ value: ShareViewController) {
        self.value = value
    }
}
