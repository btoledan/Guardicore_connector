// AddAggregatorSheet.swift — Gardicol Connector
// Add or edit an aggregator address under a thin environment.

import SwiftUI

struct AddAggregatorSheet: View {
    let envID: UUID
    var editing: GuardicoreAggregator? = nil

    @EnvironmentObject var thinEnvStore: ThinEnvStore
    @Environment(\.dismiss) var dismiss

    @State private var address: String
    @State private var label:   String

    private var isEditing: Bool { editing != nil }

    private var canSave: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(envID: UUID, editing: GuardicoreAggregator? = nil) {
        self.envID = envID
        self.editing = editing
        _address = State(initialValue: editing?.address ?? GuardicoreAggregator.defaultAddress)
        _label   = State(initialValue: editing?.label ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 32))
                    .foregroundColor(.teal)
                Text(isEditing ? "Edit Aggregator" : "Add Aggregator")
                    .font(.title2.bold())
                Text("Enter the aggregator address. Credentials default to root / tisctmt1.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aggregator Address")
                        .font(.caption).foregroundColor(.secondary)
                    TextField(GuardicoreAggregator.defaultAddress, text: $address)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Label  (optional)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("e.g. Aggr 2", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                }
            }
            .padding(.horizontal, 28)

            Button(action: save) {
                Label(isEditing ? "Save" : "Add Aggregator", systemImage: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
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
        let trimAddress = address.trimmingCharacters(in: .whitespaces)
        let trimLabel   = label.trimmingCharacters(in: .whitespaces)

        if var aggregator = editing {
            aggregator.address = trimAddress
            aggregator.label   = trimLabel
            thinEnvStore.updateAggregator(aggregator, inEnvID: envID)
        } else {
            let aggregator = GuardicoreAggregator(address: trimAddress, label: trimLabel)
            thinEnvStore.addAggregator(aggregator, toEnvID: envID)
        }
        dismiss()
    }
}
