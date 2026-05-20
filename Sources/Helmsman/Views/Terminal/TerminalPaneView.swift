// TerminalPaneView.swift — Helmsman
// Wraps TerminalKit's NSViewRepresentable and overlays reconnect UI.

import SwiftUI
import TerminalKit

struct TerminalPaneView: View {
    @ObservedObject var session: TerminalSession
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // The terminal itself
            TerminalViewRepresentable(session: session, colorScheme: colorScheme)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Disconnected overlay
            if case .disconnected(let code) = session.status {
                disconnectedOverlay(exitCode: code)
            }

            // Reconnecting spinner
            if session.status == .reconnecting {
                reconnectingOverlay
            }
        }
    }

    // MARK: - Overlays

    private func disconnectedOverlay(exitCode: Int32?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.largeTitle)
            Text("Session Disconnected")
                .font(.headline)
            if let code = exitCode, code != 0 {
                Text("Exit code: \(code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Transcript saved to: \(session.transcriptWriter.logFileURL.path)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Reconnect") { session.reconnect() }
                    .buttonStyle(.borderedProminent)
                Button("Reveal Transcript") { session.transcriptWriter.revealInFinder() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(AppTheme.surface.elevated, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private var reconnectingOverlay: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Reconnecting… (attempt \(session.reconnectAttempts))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.surface.elevated, in: Capsule())
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
