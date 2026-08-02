import AppKit
import Carbon

extension SettingsView {
func buildAboutPane() -> NSView {
        let stack = paneStack(spacing: 0)
        stack.alignment = .leading
        stack.identifier = NSUserInterfaceItemIdentifier("about-content")

        let version = makeAboutMetadataRow(
            title: L10n.aboutVersionTitle,
            value: aboutVersionValueString()
        )
        aboutVersionLabel = version.value
        stack.addArrangedSubview(version.row)
        stack.addArrangedSubview(makeAboutMetadataRow(
            title: L10n.aboutCompatibilityTitle,
            value: L10n.aboutCompatibilityValue
        ).row)
        stack.addArrangedSubview(makeAboutMetadataRow(
            title: L10n.aboutSystemRequirementTitle,
            value: L10n.aboutSystemRequirementValue
        ).row)

        stack.addArrangedSubview(aboutSpacer(height: 22))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutIntroductionTitle))
        stack.addArrangedSubview(aboutSpacer(height: 8))
        for paragraph in [
            L10n.aboutIntroductionFirst,
            L10n.aboutIntroductionSecond,
            L10n.aboutIntroductionThird,
        ] {
            let label = aboutBodyLabel(paragraph)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            stack.addArrangedSubview(aboutSpacer(height: 7))
        }

        stack.addArrangedSubview(aboutSpacer(height: 11))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutWebsiteTitle))
        stack.addArrangedSubview(aboutSpacer(height: 6))
        let website = makeAboutActionRow(
            title: L10n.aboutWebsiteURL,
            action: #selector(openWebsite)
        )
        stack.addArrangedSubview(website.row)

        stack.addArrangedSubview(aboutSpacer(height: 20))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutRelatedLinksTitle))
        stack.addArrangedSubview(aboutSpacer(height: 6))

        let updateRow = makeUpdateRow()
        stack.addArrangedSubview(updateRow)

        let license = makeAboutActionRow(
            title: L10n.aboutLicense,
            action: #selector(openLicense)
        )
        aboutLicenseTitleLabel = license.title
        stack.addArrangedSubview(license.row)

        let repo = makeAboutActionRow(
            title: L10n.aboutSourceCode,
            action: #selector(openSourceRepo)
        )
        aboutSourceTitleLabel = repo.title
        stack.addArrangedSubview(repo.row)

        let star = makeAboutActionRow(
            title: L10n.aboutStarOnGitHub,
            action: #selector(openStarOnGitHub)
        )
        aboutStarTitleLabel = star.title
        stack.addArrangedSubview(star.row)

        let featureRequest = makeAboutActionRow(
            title: L10n.aboutFeatureRequest,
            action: #selector(openFeatureRequest)
        )
        aboutFeatureRequestTitleLabel = featureRequest.title
        stack.addArrangedSubview(featureRequest.row)

        let bugReport = makeAboutActionRow(
            title: L10n.aboutBugReport,
            action: #selector(openBugReport)
        )
        aboutBugReportTitleLabel = bugReport.title
        stack.addArrangedSubview(bugReport.row)

        let errorLog = makeAboutActionRow(
            title: L10n.aboutErrorLog,
            action: #selector(showErrorLogWindow)
        )
        errorLogTitleLabel = errorLog.title
        stack.addArrangedSubview(errorLog.row)

        stack.addArrangedSubview(aboutSpacer(height: 20))
        stack.addArrangedSubview(aboutSectionTitle(L10n.aboutAcknowledgementsTitle))
        stack.addArrangedSubview(aboutSpacer(height: 8))
        for acknowledgement in [
            L10n.aboutAcknowledgementFirst,
            L10n.aboutAcknowledgementSecond,
            L10n.aboutAcknowledgementThird,
            L10n.aboutAcknowledgementFourth,
            L10n.aboutAcknowledgementFifth,
            L10n.aboutAcknowledgementSixth,
        ] {
            let label = aboutBodyLabel(acknowledgement)
            stack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            stack.addArrangedSubview(aboutSpacer(height: 7))
        }

        return wrapPane(stack, topInset: 18)
    }

    private struct AboutMetadataRowBuild {
        let row: NSView
        let value: NSTextField
    }

    private func makeAboutMetadataRow(title: String, value: String) -> AboutMetadataRowBuild {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = SettingsPalette.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        valueLabel.textColor = SettingsPalette.secondaryText

        let row = NSStackView(views: [titleLabel, valueLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 25).isActive = true
        return AboutMetadataRowBuild(row: row, value: valueLabel)
    }

    private func aboutSectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = SettingsPalette.primaryText
        return label
    }

    private func aboutBodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = SettingsPalette.secondaryText
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func aboutSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    @objc private func showErrorLogWindow() {
        if errorLogWindowController == nil {
            errorLogWindowController = ErrorLogWindowController()
        }
        errorLogWindowController?.show(relativeTo: window)
    }

    func closeErrorLogWindow() {
        errorLogWindowController?.close()
    }

    private struct AboutActionRowBuild {
        let row: NSView
        let title: NSTextField
        let detail: NSTextField
        let button: NSButton?
    }

    /// Plain text link used by the document-style About page.
    private func makeAboutActionRow(
        title: String,
        detail: String = "",
        action: Selector? = nil
    ) -> AboutActionRowBuild {
        let row: NSView
        let button: HoverButton?
        if let action {
            let link = HoverButton()
            link.target = self
            link.action = action
            link.title = ""
            link.isBordered = false
            link.cornerRadius = 0
            link.showsHoverBackground = false
            link.setAccessibilityLabel(title)
            row = link
            button = link
        } else {
            row = NSView()
            button = nil
        }
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = SettingsPalette.secondaryText
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.isHidden = detail.isEmpty

        let contentStack = NSStackView(views: [titleLabel, detailLabel])
        contentStack.orientation = .horizontal
        contentStack.alignment = .firstBaseline
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(contentStack)
        button?.interactiveContentView = contentStack
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.aboutLinkRowHeight),
            contentStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            contentStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return AboutActionRowBuild(
            row: row,
            title: titleLabel,
            detail: detailLabel,
            button: button
        )
    }

    @objc private func openSourceRepo() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://www.aulyc.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openLicense() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/blob/main/LICENSE") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openStarOnGitHub() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openFeatureRequest() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/issues/new?template=feature_request.yml") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openBugReport() {
        if let url = URL(string: "https://github.com/aulyc/aulycShot/issues/new?template=bug_report.yml") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Compact update link whose trailing status tracks the current update state.
    private func makeUpdateRow() -> NSView {
        let update = makeAboutActionRow(
            title: L10n.aboutUpdateTitle,
            action: #selector(aboutUpdateButtonClicked)
        )
        aboutUpdateTitleLabel = update.title
        aboutUpdateStatusLabel = update.detail
        aboutUpdateButton = update.button

        refreshUpdateRow()
        return update.row
    }

    @objc private func aboutUpdateButtonClicked() {
        switch UpdateChecker.shared.state {
        case .available(let version):
            StatusBarController.presentUpdateAvailableAlertAfterRefresh(fallbackVersion: version)
        case .installFailed:
            if let url = UpdateChecker.shared.latestPageURL {
                NSWorkspace.shared.open(url)
            }
        default:
            UpdateChecker.shared.check(manual: true)
        }
    }

    /// Syncs the Updates row to the current check state.
    @objc func refreshUpdateRow() {
        guard let statusLabel = aboutUpdateStatusLabel, let button = aboutUpdateButton else { return }
        let dim = NSColor.white.withAlphaComponent(0.55)
        let accent = NSColor(calibratedRed: 0.42, green: 0.66, blue: 0.98, alpha: 1.0)
        let warn = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.45, alpha: 1.0)

        switch UpdateChecker.shared.state {
        case .idle:
            statusLabel.stringValue = ""
            statusLabel.textColor = dim
            button.isEnabled = true
        case .checking:
            statusLabel.stringValue = L10n.updateChecking
            statusLabel.textColor = dim
            button.isEnabled = false
        case .upToDate:
            statusLabel.stringValue = L10n.updateUpToDateStatus
            statusLabel.textColor = dim
            button.isEnabled = true
        case .available(let version):
            statusLabel.stringValue = L10n.updateNewVersionStatus(version)
            statusLabel.textColor = accent
            button.isEnabled = true
        case .downloading(_, let fraction):
            statusLabel.stringValue = L10n.updateDownloadingStatus(Int(fraction * 100))
            statusLabel.textColor = accent
            button.isEnabled = false
        case .installing:
            statusLabel.stringValue = L10n.updateInstallingStatus
            statusLabel.textColor = accent
            button.isEnabled = false
        case .failed:
            statusLabel.stringValue = L10n.updateFailedStatus
            statusLabel.textColor = warn
            button.isEnabled = true
        case .installFailed:
            statusLabel.stringValue = L10n.updateInstallFailedStatus
            statusLabel.textColor = warn
            button.isEnabled = true
        }
        statusLabel.isHidden = statusLabel.stringValue.isEmpty
        let accessibilityStatus = statusLabel.stringValue
        button.setAccessibilityLabel(
            accessibilityStatus.isEmpty
                ? L10n.aboutUpdateTitle
                : "\(L10n.aboutUpdateTitle) \(accessibilityStatus)"
        )
    }

}
