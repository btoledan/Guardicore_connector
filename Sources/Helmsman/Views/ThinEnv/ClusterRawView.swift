// ClusterRawView.swift — raw kubectl outputs for debugging parsers

import SwiftUI

struct ClusterRawView: View {
    let snapshot: ClusterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(RawClusterOutputs.displayKeys, id: \.key) { item in
                rawSection(key: item.key, label: item.label)
            }
        }
    }

    private func rawSection(key: String, label: String) -> some View {
        let text = snapshot.raw.value(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        return DisclosureGroup {
            if text.isEmpty {
                Text("(empty)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    Text(text)
                        .font(.caption2.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 160)
            }
        } label: {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(text.isEmpty ? "empty" : "\(text.components(separatedBy: .newlines).count) lines")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
