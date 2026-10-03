import AppKit

private let background = NSColor(calibratedRed: 15/255, green: 18/255, blue: 22/255, alpha: 1)
private let surface = NSColor(calibratedRed: 19/255, green: 24/255, blue: 29/255, alpha: 1)
private let outline = NSColor(calibratedRed: 39/255, green: 47/255, blue: 53/255, alpha: 1)
private let accent = NSColor(calibratedRed: 0, green: 189/255, blue: 145/255, alpha: 1)
private let muted = NSColor(calibratedRed: 173/255, green: 181/255, blue: 187/255, alpha: 1)
private let failure = NSColor(calibratedRed: 1, green: 92/255, blue: 122/255, alpha: 1)

private final class Canvas: NSView {
    override var isFlipped: Bool { true }
}

private final class InstallationProgress: NSView {
    var fraction: Double = 0 {
        didSet {
            setAccessibilityValue(NSNumber(value: fraction))
            needsDisplay = true
        }
    }
    var color = accent
    override func draw(_ dirtyRect: NSRect) {
        outline.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        color.setFill()
        let filled = NSRect(x: 0, y: 0, width: bounds.width * CGFloat(min(1, max(0, fraction))), height: bounds.height)
        NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
    }
}

private final class FinanceChart: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let points: [(CGFloat, CGFloat)] = [(0,0.75),(0.15,0.62),(0.29,0.70),(0.42,0.36),(0.57,0.48),(0.72,0.18),(0.85,0.30),(1,0.06)]
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: 0, y: bounds.height * 0.9))
        baseline.line(to: NSPoint(x: bounds.width, y: bounds.height * 0.9))
        outline.setStroke(); baseline.stroke()
        let line = NSBezierPath()
        for (index, point) in points.enumerated() {
            let value = NSPoint(x: point.0 * bounds.width, y: point.1 * bounds.height)
            if index == 0 { line.move(to: value) } else { line.line(to: value) }
        }
        line.lineWidth = 2.5
        accent.setStroke(); line.stroke()
    }
}

private final class SetupController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var root: Canvas!
    private var headline: NSTextField!
    private var phase: NSTextField!
    private var detail: NSTextField!
    private var location: NSTextField!
    private var browse: NSButton!
    private var action: NSButton!
    private var cancel: NSButton!
    private var titleClose: NSButton!
    private var progress: InstallationProgress!
    private var spinner: NSProgressIndicator!
    private var busy = false
    private var installed = false
    private var destination = URL(fileURLWithPath: "/Applications", isDirectory: true)
    private var process: Process?

    private func block(_ frame: NSRect, color: NSColor) {
        let view = Canvas(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        root.addSubview(view)
    }

    @discardableResult private func label(_ text: String, _ frame: NSRect, size: CGFloat, color: NSColor = .white, bold: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.frame = frame
        field.font = NSFont(name: bold ? "Inter-Bold" : "Inter", size: size) ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        field.textColor = color
        root.addSubview(field)
        return field
    }

    private func button(_ text: String, _ frame: NSRect, selector: Selector, primary: Bool = false) -> NSButton {
        let button = NSButton(title: text, target: self, action: selector)
        button.frame = frame
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.backgroundColor = (primary ? accent : surface).cgColor
        button.layer?.borderColor = (primary ? accent : outline).cgColor
        button.layer?.borderWidth = 1
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: primary ? background : NSColor.white,
        ])
        root.addSubview(button)
        return button
    }

    private func rename(_ button: NSButton, _ text: String, primary: Bool = false) {
        button.title = text
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: primary ? background : NSColor.white,
        ])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !FileManager.default.isWritableFile(atPath: destination.path) {
            destination = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "Yutaka Setup"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = background
        window.delegate = self
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = true
        }
        root = Canvas(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        window.contentView = root
        block(NSRect(x: 0, y: 0, width: 960, height: 76), color: surface)
        block(NSRect(x: 0, y: 76, width: 960, height: 1), color: outline)
        block(NSRect(x: 0, y: 77, width: 244, height: 563), color: surface)
        block(NSRect(x: 244, y: 77, width: 1, height: 563), color: outline)
        if let iconURL = Bundle.main.url(forResource: "icon", withExtension: "png"), let icon = NSImage(contentsOf: iconURL) {
            for rect in [NSRect(x: 22, y: 18, width: 38, height: 38), NSRect(x: 32, y: 119, width: 92, height: 92)] {
                let image = NSImageView(frame: rect)
                image.image = icon
                image.imageScaling = .scaleProportionallyUpOrDown
                root.addSubview(image)
            }
        }
        label("Yutaka", NSRect(x: 74, y: 15, width: 300, height: 26), size: 19, bold: true)
        label("DESKTOP SETUP", NSRect(x: 75, y: 43, width: 300, height: 20), size: 11, color: muted)
        label("Yutaka", NSRect(x: 32, y: 235, width: 180, height: 42), size: 30, bold: true)
        label("Your finances,\nin your control.", NSRect(x: 32, y: 293, width: 180, height: 64), size: 16, color: muted)
        root.addSubview(FinanceChart(frame: NSRect(x: 32, y: 400, width: 180, height: 72)))
        label("LOCAL FIRST · PRIVATE", NSRect(x: 32, y: 552, width: 190, height: 22), size: 11, color: accent, bold: true)
        label("macOS desktop", NSRect(x: 32, y: 584, width: 180, height: 22), size: 13, color: muted)
        headline = label("Your finances.\nYour control.", NSRect(x: 290, y: 118, width: 620, height: 104), size: 36, bold: true)
        label("Track accounts, expenses and plans in one place.", NSRect(x: 292, y: 235, width: 610, height: 46), size: 16, color: muted)
        label("Install location", NSRect(x: 292, y: 306, width: 600, height: 22), size: 13, color: muted)
        block(NSRect(x: 292, y: 334, width: 477, height: 38), color: surface)
        location = label(destination.path, NSRect(x: 304, y: 342, width: 453, height: 24), size: 13, color: muted)
        location.maximumNumberOfLines = 1
        location.lineBreakMode = .byTruncatingMiddle
        location.isSelectable = true
        location.setAccessibilityLabel("Install location")
        browse = button("Browse…", NSRect(x: 781, y: 334, width: 132, height: 38), selector: #selector(chooseFolder))
        phase = label("READY TO INSTALL", NSRect(x: 292, y: 446, width: 620, height: 24), size: 12, color: accent, bold: true)
        progress = InstallationProgress(frame: NSRect(x: 292, y: 478, width: 621, height: 6))
        progress.setAccessibilityElement(true)
        progress.setAccessibilityRole(.progressIndicator)
        progress.setAccessibilityLabel("Installation progress")
        root.addSubview(progress)
        detail = label("Your accounts, transactions and settings stay in place.", NSRect(x: 292, y: 504, width: 620, height: 40), size: 13, color: muted)
        spinner = NSProgressIndicator(frame: NSRect(x: 292, y: 415, width: 18, height: 18))
        spinner.style = .spinning
        spinner.isHidden = true
        root.addSubview(spinner)
        cancel = button("Cancel", NSRect(x: 619, y: 560, width: 132, height: 48), selector: #selector(closeSetup))
        cancel.keyEquivalent = "\u{1b}"
        action = button("Install Yutaka", NSRect(x: 767, y: 560, width: 146, height: 48), selector: #selector(installOrLaunch), primary: true)
        action.keyEquivalent = "\r"
        titleClose = button("×", NSRect(x: 890, y: 18, width: 44, height: 38), selector: #selector(closeSetup))
        titleClose.setAccessibilityLabel("Close installer")
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--check-ui") {
            root.layoutSubtreeIfNeeded()
            precondition(root.subviews.allSatisfy { root.bounds.contains($0.frame) }, "Setup controls must fit inside the window")
            print("Yutaka setup UI is ready.")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { busy ? .terminateCancel : .terminateNow }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !busy }

    @objc private func closeSetup() { if !busy { window.close() } }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose where to install Yutaka"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination
        if panel.runModal() == .OK, let folder = panel.url {
            destination = folder
            location.stringValue = folder.path
        }
    }

    private func setBusy(_ value: Bool) {
        busy = value
        browse.isEnabled = !value && !installed
        for button in [action, cancel, titleClose] { button?.isEnabled = !value }
        spinner.isHidden = !value || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if spinner.isHidden { spinner.stopAnimation(nil) } else { spinner.startAnimation(nil) }
    }

    private func showError(_ message: String) {
        phase.stringValue = "INSTALLATION FAILED"
        phase.textColor = failure
        detail.stringValue = String(message.prefix(220))
        detail.toolTip = message
        progress.color = failure
        progress.needsDisplay = true
        rename(action, "Try again", primary: true)
        setBusy(false)
    }

    @objc private func installOrLaunch() {
        if busy { return }
        if installed {
            if NSWorkspace.shared.open(destination.appendingPathComponent("Yutaka.app")) { window.close() }
            else { detail.stringValue = "Open Yutaka from your Applications folder." }
            return
        }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.yutaka.siam")
        if !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Close Yutaka to install the update"
            alert.informativeText = "Finish any edits first. Setup will ask Yutaka to quit normally."
            alert.addButton(withTitle: "Quit and continue")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return }
            running.forEach { _ = $0.terminate() }
            setBusy(true)
            phase.stringValue = "WAITING FOR YUTAKA"
            detail.stringValue = "Closing the app before installing…"
            var attempts = 0
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                attempts += 1
                if NSRunningApplication.runningApplications(withBundleIdentifier: "com.yutaka.siam").isEmpty {
                    timer.invalidate(); self.startInstallation()
                } else if attempts >= 30 {
                    timer.invalidate(); self.showError("Yutaka is still running. Close it, then try again.")
                }
            }
        } else { startInstallation() }
    }

    private func startInstallation() {
        guard let resources = Bundle.main.resourceURL else { showError("Setup resources are missing."); return }
        setBusy(true)
        headline.stringValue = "Getting Yutaka\nready for you."
        phase.stringValue = "INSTALLING YUTAKA"
        phase.textColor = accent
        detail.stringValue = "Preparing installation…"
        progress.color = accent
        progress.fraction = 0
        let task = Process()
        let output = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [resources.appendingPathComponent("install.sh").path, resources.path, destination.path]
        task.standardOutput = output
        task.standardError = output
        do { try task.run() } catch { showError("Could not start installation. Please try again."); return }
        process = task
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var pending = Data()
            var friendlyError: String?
            while true {
                let data = output.fileHandleForReading.availableData
                if data.isEmpty { break }
                pending.append(data)
                while let end = pending.firstIndex(of: 10) {
                    let line = String(decoding: pending[..<end], as: UTF8.self)
                    pending.removeSubrange(...end)
                    let parts = line.split(separator: ":", maxSplits: 2).map(String.init)
                    if parts.count == 3, parts[0] == "PROGRESS", let percent = Double(parts[1]) {
                        DispatchQueue.main.async {
                            self?.progress.fraction = percent / 100
                            self?.phase.stringValue = "INSTALLING YUTAKA · \(Int(percent))%"
                            self?.detail.stringValue = parts[2]
                        }
                    } else if line.hasPrefix("ERROR: ") {
                        friendlyError = String(line.dropFirst(7))
                    }
                }
            }
            task.waitUntilExit()
            let errorMessage = friendlyError ?? "Installation failed. Check that the folder is writable, then try again."
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil
                if task.terminationStatus == 0 {
                    self.installed = true
                    self.progress.fraction = 1
                    self.headline.stringValue = "Make yourself\nat home."
                    self.phase.stringValue = "INSTALLATION COMPLETE"
                    self.detail.stringValue = "Yutaka is ready. Open it from your Applications folder anytime."
                    self.rename(self.action, "Launch Yutaka", primary: true)
                    self.rename(self.cancel, "Done")
                    self.setBusy(false)
                } else {
                    self.showError(errorMessage)
                }
            }
        }
    }
}

let app = NSApplication.shared
private let controller = SetupController()
app.setActivationPolicy(.regular)
app.delegate = controller
app.run()
