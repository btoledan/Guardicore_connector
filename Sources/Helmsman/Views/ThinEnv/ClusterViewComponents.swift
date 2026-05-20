// ClusterViewComponents.swift — shared Cluster View UI pieces

import SwiftUI
import TerminalKit

enum ClusterPanelTab: String, CaseIterable, Identifiable {
    case overview  = "Overview"
    case topology  = "Topology"
    case guardicore = "GC"
    case digestion = "Digest"
    case policies  = "Policies"
    case traffic   = "Traffic"
    case commands  = "Commands"
    case raw       = "Raw"
    var id: String { rawValue }
}

struct ClusterMetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.text.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

struct ClusterStatusBanner: View {
    let status: ClusterHealthStatus
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                Text(status.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundColor(status.color)
            }
            ForEach(warnings.prefix(3), id: \.self) { w in
                Text(w)
                    .font(.caption2)
                    .foregroundColor(AppTheme.text.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ClusterWarningList: View {
    let warnings: [String]

    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Partial data warnings")
                    .font(.caption2.bold())
                    .foregroundColor(AppTheme.semantic.warning)
                ForEach(warnings, id: \.self) { w in
                    Text("• \(w)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.text.secondary)
                }
            }
            .padding(8)
            .background(AppTheme.semantic.warning.opacity(0.08))
            .cornerRadius(8)
        }
    }
}

struct ClusterTerminalActionButton: View {
    let label: String
    let command: String
    let session: TerminalSession
    @State private var didRun = false

    var body: some View {
        Button {
            session.run(command)
            didRun = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didRun = false }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: didRun ? "checkmark.circle.fill" : "terminal")
                    .font(.caption2)
                    .foregroundColor(didRun ? AppTheme.semantic.success : AppTheme.text.secondary)
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundColor(AppTheme.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.left")
                    .font(.caption2)
                    .foregroundColor(AppTheme.text.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(didRun ? AppTheme.semantic.success.opacity(0.12) : AppTheme.surface.elevated)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help("Types into the cluster terminal on the left:\n\(command)")
    }
}

struct ClusterEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(AppTheme.text.muted)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.text.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppTheme.text.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
