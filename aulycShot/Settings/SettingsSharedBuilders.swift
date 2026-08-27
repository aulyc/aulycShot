import AppKit
import Carbon

extension SettingsView {
// MARK: - Builders

    func paneStack(spacing: CGFloat = 14) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func wrapPane(_ stack: NSStackView, topInset: CGFloat = 18) -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: topInset),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -28),
        ])
        return host
    }

    static let settingsRowMinimumHeight: CGFloat = 52
    static let aboutLinkRowHeight: CGFloat = 28

    func generalCard() -> CardView {
        let card = CardView()
        card.showsTopBorder = false
        return card
    }

    func constrainSettingsRowHeight(_ row: NSView) {
        row.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Self.settingsRowMinimumHeight
        ).isActive = true
    }

    func verticalInnerStack() -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    func rowDivider() -> NSView {
        let v = HairlineSeparatorView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    func flexSpacer() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.init(1), for: .horizontal)
        v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return v
    }

    func primaryLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        l.textColor = SettingsPalette.primaryText
        return l
    }

    func secondaryLabel(_ text: String, wrapping: Bool = false) -> NSTextField {
        let l = wrapping ? NSTextField(wrappingLabelWithString: text) : NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 11)
        l.textColor = SettingsPalette.secondaryText
        if wrapping {
            l.preferredMaxLayoutWidth = 360
        }
        return l
    }

    func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom),
        ])
    }

    struct ShortcutCardBuild {
        let card: CardView
        let title: NSTextField
        let field: NSTextField
        let setButton: NSButton
    }

    func buildShortcutCard(
        title: String,
        setAction: Selector
    ) -> ShortcutCardBuild {
        let card = generalCard()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        pin(inner, to: card, insets: NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(flexSpacer())

        let field = NSTextField()
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        field.textColor = NSColor.white.withAlphaComponent(0.92)
        field.translatesAutoresizingMaskIntoConstraints = false

        let fieldBackground = NSView()
        fieldBackground.wantsLayer = true
        fieldBackground.layer?.cornerRadius = 8
        fieldBackground.layer?.cornerCurve = .continuous
        fieldBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        fieldBackground.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        fieldBackground.layer?.borderWidth = 1
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false
        fieldBackground.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerYAnchor.constraint(equalTo: fieldBackground.centerYAnchor),
            field.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -10),
            fieldBackground.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            fieldBackground.heightAnchor.constraint(equalToConstant: 34),
        ])
        row.addArrangedSubview(fieldBackground)

        let setButton = SettingsActionButton(
            title: L10n.shortcutSet,
            target: self,
            action: setAction
        )
        configureGeneralActionButton(setButton)
        row.addArrangedSubview(setButton)

        inner.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        constrainSettingsRowHeight(row)

        return ShortcutCardBuild(
            card: card,
            title: titleLabel,
            field: field,
            setButton: setButton
        )
    }

    struct ActivationRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let picker: NSPopUpButton
    }

    func makeActivationRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        identifier: String,
        action: Selector
    ) -> ActivationRowBuild {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        var subtitleLabel: NSTextField? = nil
        if let subtitle {
            let sub = secondaryLabel(subtitle, wrapping: true)
            textStack.addArrangedSubview(sub)
            subtitleLabel = sub
        }

        let picker = SettingsPopUpButton(frame: .zero, pullsDown: false)
        picker.identifier = NSUserInterfaceItemIdentifier(identifier)
        picker.target = self
        picker.action = action
        picker.controlSize = .small
        picker.font = NSFont.systemFont(ofSize: 12)
        constrainGeneralPopupWidth(picker)
        refreshActivationPicker(picker, isEnabled: isOn)

        row.addSubview(textStack)
        row.addSubview(picker)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: picker.leadingAnchor, constant: -12),

            picker.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            picker.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])
        constrainSettingsRowHeight(row)

        return ActivationRowBuild(
            row: row,
            title: titleLabel,
            subtitle: subtitleLabel,
            picker: picker
        )
    }

    func refreshActivationPicker(
        _ picker: NSPopUpButton?,
        isEnabled: Bool
    ) {
        guard let picker else { return }
        let selectedState = SettingsActivationState(isEnabled: isEnabled)
        picker.removeAllItems()
        for state in SettingsActivationState.allCases {
            picker.addItem(withTitle: state.localizedTitle)
            picker.lastItem?.representedObject = state.rawValue
        }
        if let selectedIndex = SettingsActivationState.allCases.firstIndex(of: selectedState) {
            picker.selectItem(at: selectedIndex)
        }
    }

    func selectedActivationState(
        from picker: NSPopUpButton
    ) -> SettingsActivationState? {
        guard let rawValue = picker.selectedItem?.representedObject as? String else {
            return nil
        }
        return SettingsActivationState(rawValue: rawValue)
    }

}
