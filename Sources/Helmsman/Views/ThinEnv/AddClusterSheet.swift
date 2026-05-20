// AddClusterSheet.swift — Gardicol Connector
// Cluster folder naming: type, label, IP. Connection credentials edited separately.

import SwiftUI

struct AddClusterSheet: View {
    let envID: UUID
    var editing: GuardicoreCluster? = nil

    @EnvironmentObject var thinEnvStore: ThinEnvStore
    @Environment(\.dismiss) var dismiss

    @State private var clusterType: GuardicoreCluster.ClusterType
    @State private var label:       String
    @State private var customIP:    String

    private var isEditing: Bool { editing != nil }

    init(envID: UUID, editing: GuardicoreCluster? = nil) {
        self.envID = envID
        self.editing = editing
        _clusterType = State(initialValue: editing?.type ?? .rancher)
        _label       = State(initialValue: editing?.label ?? "")
        _customIP    = State(initialValue: editing?.customIP ?? "")
    }

    private var canSave: Bool {
        clusterType != .custom || !customIP.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text(isEditing ? "Edit Cluster" : "Add Cluster")
                    .font(.title2.bold())
                Text("Cluster name and target IP — SSH credentials are edited separately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cluster Type")
                        .font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $clusterType) {
                        ForEach(GuardicoreCluster.ClusterType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if clusterType != .custom {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.secondary)
                        Text(clusterType.defaultIP)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                if clusterType == .custom {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cluster IP")
                            .font(.caption).foregroundColor(.secondary)
                        TextField("172.17.x.x", text: $customIP)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Label  (optional)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("e.g. Machine Tester", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                }
            }
            .padding(.horizontal, 28)

            Button(action: save) {
                Label(isEditing ? "Save" : "Add Cluster", systemImage: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave)
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .frame(width: 360)
    }

    private func save() {
        guard canSave else { return }
        let trimLabel = label.trimmingCharacters(in: .whitespaces)
        let trimIP = customIP.trimmingCharacters(in: .whitespaces)

        if var cluster = editing {
            cluster.type = clusterType
            cluster.label = trimLabel
            cluster.customIP = trimIP
            thinEnvStore.updateCluster(cluster, inEnvID: envID)
        } else {
            let cluster = GuardicoreCluster(
                type:     clusterType,
                label:    trimLabel,
                customIP: trimIP
            )
            thinEnvStore.addCluster(cluster, toEnvID: envID)
        }
        dismiss()
    }
}
