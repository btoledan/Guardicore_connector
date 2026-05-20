// AddThinEnvSheet.swift — Gardicol Connector
// Folder naming only: env number + optional label. No connection credentials here.

import SwiftUI

struct AddThinEnvSheet: View {
    var editing: ThinEnvironment? = nil

    @EnvironmentObject var thinEnvStore: ThinEnvStore
    @Environment(\.dismiss) var dismiss

    @State private var envNumberText: String = ""
    @State private var label:         String = ""
    @State private var username:      String = ThinEnvironment.defaultUser
    @State private var password:      String = ThinEnvironment.defaultPassword
    @FocusState private var focused:  Bool

    private var isEditing: Bool { editing != nil }
    private var envNumber: Int? { Int(envNumberText.trimmingCharacters(in: .whitespaces)) }
    private var canSave: Bool { envNumber != nil }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                Text(isEditing ? "Edit Thin Environment" : "Add Thin Environment")
                    .font(.title2.bold())
                Text("Enter the env number (e.g. 438 → 438.thin.env) and default credentials. Individual machine credentials can be edited later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Environment Number")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("438", text: $envNumberText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit { save() }
                    if let n = envNumber {
                        Text("\(n).thin.env")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Folder Label  (optional)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("e.g. customer-demo", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                }

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Username")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Password")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 28)

            Button(action: save) {
                Label(isEditing ? "Save" : "Add Thin Environment", systemImage: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
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
        .onAppear {
            if let env = editing {
                envNumberText = String(env.envNumber)
                label = env.label
                username = env.username
                password = env.password
            }
            focused = true
        }
    }

    private func save() {
        guard let n = envNumber else { return }
        let trimLabel = label.trimmingCharacters(in: .whitespaces)

        if var env = editing {
            env.envNumber = n
            env.label = trimLabel
            env.username = username
            env.password = password
            thinEnvStore.update(env)
        } else {
            thinEnvStore.add(ThinEnvironment(
                envNumber: n,
                label: trimLabel,
                username: username,
                password: password,
                mgmtUsername: username,
                mgmtPassword: password
            ))
        }
        dismiss()
    }
}
