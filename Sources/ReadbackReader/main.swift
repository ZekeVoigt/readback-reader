import AppKit
import ApplicationServices
import Carbon
import SwiftUI

private let appName = "Readback Reader"

@main
struct ReadbackReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSSpeechSynthesizerDelegate {
    private var statusItem: NSStatusItem?
    private var speechSynthesizer = NSSpeechSynthesizer()
    private var voices: [VoiceOption] = []
    private var selectedVoiceIdentifier: NSSpeechSynthesizer.VoiceName = NSSpeechSynthesizer.defaultVoice
    private var speed: Double = 1.0
    private var lastText: String = ""
    private var isPaused = false
    private var hotKeyRefs: [EventHotKeyRef?] = []

    private let speedValues: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private let preferredVoiceNames = [
        "Samantha",
        "Flo (English (US))",
        "Shelley (English (US))",
        "Reed (English (US))"
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadPreferences()
        configureVoices()
        configureStatusItem()
        registerHotKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyRefs.compactMap { $0 }.forEach { UnregisterEventHotKey($0) }
    }

    private func loadPreferences() {
        let storedSpeed = UserDefaults.standard.double(forKey: "speed")
        speed = storedSpeed == 0 ? 1.0 : storedSpeed
        if let storedVoice = UserDefaults.standard.string(forKey: "voiceIdentifier"), !storedVoice.isEmpty {
            selectedVoiceIdentifier = NSSpeechSynthesizer.VoiceName(rawValue: storedVoice)
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(speed, forKey: "speed")
        UserDefaults.standard.set(selectedVoiceIdentifier.rawValue, forKey: "voiceIdentifier")
    }

    private func configureVoices() {
        let availableVoiceOptions = NSSpeechSynthesizer.availableVoices.compactMap { identifier in
            let attrs = NSSpeechSynthesizer.attributes(forVoice: identifier)
            let name = attrs[NSSpeechSynthesizer.VoiceAttributeKey(rawValue: "VoiceName")] as? String ?? identifier.rawValue
            let locale = attrs[.localeIdentifier] as? String ?? ""
            return VoiceOption(identifier: identifier, name: name, locale: locale)
        }

        voices = preferredVoiceNames.compactMap { preferredName in
            availableVoiceOptions.first { $0.name == preferredName }
        }

        if voices.count < 4 {
            let backupNames = ["Samantha", "Karen", "Daniel", "Moira", "Tessa"]
            for backupName in backupNames {
                if voices.count >= 4 {
                    break
                }
                if let backup = availableVoiceOptions.first(where: { $0.name == backupName }),
                   !voices.contains(where: { $0.identifier == backup.identifier }) {
                    voices.append(backup)
                }
            }
        }

        if !voices.contains(where: { $0.identifier == selectedVoiceIdentifier }) {
            selectedVoiceIdentifier = voices.first?.identifier
                ?? NSSpeechSynthesizer.defaultVoice
        }

        speechSynthesizer.delegate = self
        speechSynthesizer.setVoice(selectedVoiceIdentifier)
        speechSynthesizer.rate = rateForSpeed(speed)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Readback"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let readSelection = NSMenuItem(title: "Read Selection", action: #selector(readSelectionAction), keyEquivalent: "r")
        readSelection.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(readSelection)

        let readClipboard = NSMenuItem(title: "Read Clipboard", action: #selector(readClipboardAction), keyEquivalent: "")
        menu.addItem(readClipboard)

        let reread = NSMenuItem(title: "Read Last Text Again", action: #selector(readLastTextAction), keyEquivalent: "")
        reread.isEnabled = !lastText.isEmpty
        menu.addItem(reread)

        menu.addItem(.separator())

        let pauseTitle = isPaused ? "Resume" : "Pause"
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(togglePauseAction), keyEquivalent: ""))

        let stop = NSMenuItem(title: "Stop", action: #selector(stopAction), keyEquivalent: "s")
        stop.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(stop)

        menu.addItem(.separator())

        let speedMenu = NSMenu()
        for value in speedValues {
            let item = NSMenuItem(title: String(format: "%.2gx", value), action: #selector(selectSpeedAction(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = abs(value - speed) < 0.001 ? .on : .off
            speedMenu.addItem(item)
        }
        let speedParent = NSMenuItem(title: "Speed: \(String(format: "%.2gx", speed))", action: nil, keyEquivalent: "")
        speedParent.submenu = speedMenu
        menu.addItem(speedParent)

        let voiceMenu = NSMenu()
        for voice in voices {
            let item = NSMenuItem(title: voice.menuTitle, action: #selector(selectVoiceAction(_:)), keyEquivalent: "")
            item.representedObject = voice.identifier
            item.state = voice.identifier == selectedVoiceIdentifier ? .on : .off
            voiceMenu.addItem(item)
        }
        let currentVoice = voices.first(where: { $0.identifier == selectedVoiceIdentifier })?.name ?? "Default"
        let voiceParent = NSMenuItem(title: "Voice: \(currentVoice)", action: nil, keyEquivalent: "")
        voiceParent.submenu = voiceMenu
        menu.addItem(voiceParent)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "How to Use", action: #selector(showHelpAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettingsAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(quitAction), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func readSelectionAction() {
        readSelectedText()
    }

    @objc private func readClipboardAction() {
        readClipboard()
    }

    @objc private func readLastTextAction() {
        speak(lastText)
    }

    @objc private func togglePauseAction() {
        guard speechSynthesizer.isSpeaking else { return }

        if isPaused {
            speechSynthesizer.continueSpeaking()
        } else {
            speechSynthesizer.pauseSpeaking(at: .immediateBoundary)
        }

        isPaused.toggle()
        rebuildMenu()
    }

    @objc private func stopAction() {
        speechSynthesizer.stopSpeaking()
        isPaused = false
        rebuildMenu()
    }

    @objc private func selectSpeedAction(_ sender: NSMenuItem) {
        guard let newSpeed = sender.representedObject as? Double else { return }
        speed = newSpeed
        speechSynthesizer.rate = rateForSpeed(speed)
        savePreferences()
        rebuildMenu()
    }

    @objc private func selectVoiceAction(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? NSSpeechSynthesizer.VoiceName else { return }
        selectedVoiceIdentifier = identifier
        speechSynthesizer.setVoice(identifier)
        savePreferences()
        rebuildMenu()
    }

    @objc private func showHelpAction() {
        let alert = NSAlert()
        alert.messageText = appName
        alert.informativeText = """
        Select text in VS Code, Codex, a browser, or another app, then press Option-Command-R.

        Stop speech with Option-Command-S.

        If selection reading does nothing, grant Accessibility permission in System Settings > Privacy & Security > Accessibility, or use Read Clipboard after copying text.
        """
        alert.runModal()
    }

    @objc private func openAccessibilitySettingsAction() {
        openAccessibilitySettings()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func readSelectedText() {
        guard accessibilityPermissionGranted(prompt: true) else {
            showAccessibilityPermissionAlert()
            return
        }

        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.string(forType: .string)

        pasteboard.clearContents()

        copySelectionToClipboard()
        waitForCopiedSelection(previousClipboard: previousClipboard, attemptsRemaining: 12)
    }

    private func waitForCopiedSelection(
        previousClipboard: String?,
        attemptsRemaining: Int
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            let pasteboard = NSPasteboard.general
            let copied = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !copied.isEmpty {
                self.speak(copied)
                self.restoreClipboard(previousClipboard)
                return
            }

            if attemptsRemaining > 0 {
                self.waitForCopiedSelection(
                    previousClipboard: previousClipboard,
                    attemptsRemaining: attemptsRemaining - 1
                )
                return
            }

            self.restoreClipboard(previousClipboard)
            self.showTransientMessage("I could not read the selected text. Try copying it and choosing Read Clipboard.")
        }
    }

    private func restoreClipboard(_ previousClipboard: String?) {
        NSPasteboard.general.clearContents()
        if let previousClipboard {
            NSPasteboard.general.setString(previousClipboard, forType: .string)
        }
    }

    private func readClipboard() {
        let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            showTransientMessage("Clipboard is empty.")
        } else {
            speak(text)
        }
    }

    private func speak(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking()
        }

        lastText = cleanText
        isPaused = false
        speechSynthesizer.setVoice(selectedVoiceIdentifier)
        speechSynthesizer.rate = rateForSpeed(speed)
        speechSynthesizer.startSpeaking(cleanText)
        rebuildMenu()
    }

    private func copySelectionToClipboard() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func rateForSpeed(_ speed: Double) -> Float {
        Float(180.0 * speed)
    }

    private func showTransientMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = appName
        alert.informativeText = message
        alert.runModal()
    }

    private func accessibilityPermissionGranted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Allow Readback Reader"
        alert.informativeText = """
        macOS needs Accessibility permission before Readback Reader can copy highlighted text from other apps.

        Open Accessibility settings, enable Readback Reader, then quit and reopen Readback Reader.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Use Clipboard Instead")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        isPaused = false
        rebuildMenu()
    }
}

private struct VoiceOption {
    let identifier: NSSpeechSynthesizer.VoiceName
    let name: String
    let locale: String

    var menuTitle: String {
        locale.isEmpty ? name : "\(name) (\(locale))"
    }
}

private enum HotKeyIdentifier: UInt32 {
    case readSelection = 1
    case stop = 2
}

private extension AppDelegate {
    func registerHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard let userData else { return noErr }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                appDelegate.handleHotKey(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        registerHotKey(id: .readSelection, keyCode: UInt32(kVK_ANSI_R))
        registerHotKey(id: .stop, keyCode: UInt32(kVK_ANSI_S))
    }

    func registerHotKey(id: HotKeyIdentifier, keyCode: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("RDRB".fourCharCodeValue), id: id.rawValue)
        let modifiers = UInt32(optionKey | cmdKey)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        hotKeyRefs.append(hotKeyRef)
    }

    func handleHotKey(id: UInt32) {
        switch HotKeyIdentifier(rawValue: id) {
        case .readSelection:
            readSelectedText()
        case .stop:
            stopAction()
        case .none:
            break
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
