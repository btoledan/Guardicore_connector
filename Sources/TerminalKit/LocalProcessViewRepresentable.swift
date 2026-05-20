// LocalProcessViewRepresentable.swift — TerminalKit
// NSViewRepresentable bridge: wraps SwiftTerm's LocalProcessTerminalView
// as a SwiftUI view, hooking into TerminalSession for state and transcript.

import SwiftUI
import AppKit
import SwiftTerm

// MARK: - Transcript-capturing subclass

/// Subclasses LocalProcessTerminalView to intercept raw bytes for the transcript.
/// `dataReceived` is declared `open` in SwiftTerm so subclassing is safe.
open class TranscriptTerminalView: LocalProcessTerminalView {
    public weak var session: TerminalSession?

    open override func dataReceived(slice: ArraySlice<UInt8>) {
        session?.appendTranscript(slice)
        super.dataReceived(slice: slice)
    }

    open override func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        Task { @MainActor [weak session] in
            session?.handleTermination(exitCode: exitCode)
        }
        super.processTerminated(source, exitCode: exitCode)
    }
}

// MARK: - SwiftUI NSViewRepresentable

public struct TerminalViewRepresentable: NSViewRepresentable {
    @ObservedObject public var session: TerminalSession
    public var colorScheme: ColorScheme

    public init(session: TerminalSession, colorScheme: ColorScheme) {
        self.session     = session
        self.colorScheme = colorScheme
    }

    // MARK: NSViewRepresentable

    public func makeNSView(context: Context) -> TranscriptTerminalView {
        let view = TranscriptTerminalView(frame: .zero)
        view.session          = session
        view.terminalDelegate = context.coordinator
        applyTheme(to: view, colorScheme: colorScheme)
        // Defer process launch until the view is installed in the window
        DispatchQueue.main.async {
            Task { @MainActor in
                session.start(in: view)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: TranscriptTerminalView, context: Context) {
        applyTheme(to: nsView, colorScheme: colorScheme)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    // MARK: - Appearance

    private func applyTheme(to view: TerminalView, colorScheme: ColorScheme) {
        // SwiftTerm theme: use installColors() with a dark/light palette
        let colors = colorScheme == .dark ? TerminalColors.darkDefault : TerminalColors.lightDefault
        view.installColors(colors)
    }

    // MARK: - Coordinator (TerminalViewDelegate)

    public final class Coordinator: NSObject, TerminalViewDelegate {
        private weak var session: TerminalSession?

        init(session: TerminalSession) {
            self.session = session
        }

        public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            // Forward to LocalProcessTerminalView so the PTY window size updates.
            if let local = source as? LocalProcessTerminalView {
                local.sizeChanged(source: source, newCols: newCols, newRows: newRows)
            }
            Task { @MainActor [weak session] in
                session?.updateSize(cols: newCols, rows: newRows)
            }
        }

        public func setTerminalTitle(source: TerminalView, title: String) {
            Task { @MainActor [weak session] in
                session?.updateTitle(title)
            }
        }

        // Called when the shell broadcasts OSC 7 (current directory).
        // Enables SFTP pane to track cwd without shell integration magic.
        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            Task { @MainActor [weak session] in
                session?.updateCurrentDirectory(directory)
            }
        }

        public func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // Coordinator replaces LocalProcessTerminalView as terminalDelegate — must forward input to the PTY.
            if let local = source as? LocalProcessTerminalView {
                local.process.send(data: data)
            }
        }

        public func scrolled(source: TerminalView, position: Double) {}

        public func bell(source: TerminalView) {
            NSSound.beep()
        }

        public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            NSWorkspace.shared.open(url)
        }

        public func clipboardCopy(source: TerminalView, content: Data) {
            guard let string = String(data: content, encoding: .utf8) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }
}

// MARK: - Built-in colour palettes

public enum TerminalColors {

    // SwiftTerm Color uses UInt16 values (0–65535). Scale 8-bit values by 257 (= 65535/255).
    private static func c(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> SwiftTerm.Color {
        SwiftTerm.Color(red: r * 257, green: g * 257, blue: b * 257)
    }

    /// A dark terminal palette (near-black background, light foreground).
    public static var darkDefault: [SwiftTerm.Color] {
        [
            c(0x1e, 0x1e, 0x1e), // black
            c(0xcc, 0x00, 0x00), // red
            c(0x4e, 0x9a, 0x06), // green
            c(0xc4, 0xa0, 0x00), // yellow
            c(0x34, 0x65, 0xa4), // blue
            c(0x75, 0x50, 0x7b), // magenta
            c(0x06, 0x98, 0x9a), // cyan
            c(0xd3, 0xd7, 0xcf), // white
            // Bright variants
            c(0x55, 0x57, 0x53),
            c(0xef, 0x29, 0x29),
            c(0x8a, 0xe2, 0x34),
            c(0xfc, 0xe9, 0x4f),
            c(0x72, 0x9f, 0xcf),
            c(0xad, 0x7f, 0xa8),
            c(0x34, 0xe2, 0xe2),
            c(0xee, 0xee, 0xec),
        ]
    }

    /// A light terminal palette.
    public static var lightDefault: [SwiftTerm.Color] {
        [
            c(0xff, 0xff, 0xff),
            c(0xcc, 0x00, 0x00),
            c(0x4e, 0x9a, 0x06),
            c(0xc4, 0xa0, 0x00),
            c(0x34, 0x65, 0xa4),
            c(0x75, 0x50, 0x7b),
            c(0x06, 0x98, 0x9a),
            c(0x2e, 0x34, 0x36),
            c(0x55, 0x57, 0x53),
            c(0xef, 0x29, 0x29),
            c(0x8a, 0xe2, 0x34),
            c(0xfc, 0xe9, 0x4f),
            c(0x72, 0x9f, 0xcf),
            c(0xad, 0x7f, 0xa8),
            c(0x34, 0xe2, 0xe2),
            c(0x2e, 0x34, 0x36),
        ]
    }
}
