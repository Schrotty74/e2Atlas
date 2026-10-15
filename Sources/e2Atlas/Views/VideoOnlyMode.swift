import AppKit
import Observation
import SwiftUI

/// Owns only window presentation; the existing playback slots keep their engines.
@MainActor @Observable
final class VideoOnlyController {
    private(set) var slotIndex: Int?
    var isActive: Bool { slotIndex != nil }
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var enteredFullScreen = false
    @ObservationIgnored private var enteringFullScreen = false
    @ObservationIgnored private var savedTitleVisibility: NSWindow.TitleVisibility?
    @ObservationIgnored private var savedTitlebarTransparency = false
    @ObservationIgnored private var savedFullSizeContent = false

    func attach(_ window: NSWindow?) {
        // SwiftUI may briefly detach the reader while replacing its content.
        // Keep the containing window and its Escape monitor through that swap.
        guard let window else { return }
        guard self.window !== window else { return }
        removeObservers()
        self.window = window
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.enteringFullScreen = false
                // Escape may arrive during the native fullscreen animation.
                if !self.isActive && self.enteredFullScreen {
                    self.window?.toggleFullScreen(nil)
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restoreChrome()
                self?.slotIndex = nil
                self?.enteredFullScreen = false
                self?.enteringFullScreen = false
            }
        })
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // AppKit delivers local event monitors on the main thread.
            let consumed = MainActor.assumeIsolated {
                guard let self, self.isActive, event.window === self.window, event.keyCode == 53 else { return false }
                self.exit()
                return true
            }
            return consumed ? nil : event
        }
    }

    func enter(slot index: Int) {
        guard !isActive, let window else { return }
        savedTitleVisibility = window.titleVisibility
        savedTitlebarTransparency = window.titlebarAppearsTransparent
        savedFullSizeContent = window.styleMask.contains(.fullSizeContentView)
        slotIndex = index
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        enteredFullScreen = !window.styleMask.contains(.fullScreen)
        if enteredFullScreen {
            enteringFullScreen = true
            window.toggleFullScreen(nil)
        }
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    func exit() {
        guard isActive else { return }
        slotIndex = nil
        restoreChrome()
        if enteredFullScreen && !enteringFullScreen && window?.styleMask.contains(.fullScreen) == true {
            window?.toggleFullScreen(nil)
        }
    }

    private func restoreChrome() {
        guard let visibility = savedTitleVisibility, let window else { return }
        window.titleVisibility = visibility
        window.titlebarAppearsTransparent = savedTitlebarTransparency
        if !savedFullSizeContent { window.styleMask.remove(.fullSizeContentView) }
        savedTitleVisibility = nil
    }

    private func removeObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
    }

    isolated deinit { removeObservers() }
}

/// Captures the containing window rather than guessing the application's key window.
struct VideoWindowReader: NSViewRepresentable {
    let controller: VideoOnlyController
    func makeNSView(context: Context) -> VideoWindowReference {
        let view = VideoWindowReference()
        view.controller = controller
        return view
    }
    func updateNSView(_ view: VideoWindowReference, context: Context) {
        view.controller = controller
        controller.attach(view.window)
    }
}

final class VideoWindowReference: NSView {
    weak var controller: VideoOnlyController?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        controller?.attach(window)
    }
}
