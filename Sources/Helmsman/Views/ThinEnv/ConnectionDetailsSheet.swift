// ConnectionDetailsSheet.swift — Gardicol Connector
// Edit SSH credentials and connection targets — separate from folder naming.

import SwiftUI

enum ConnectionTarget: Identifiable {
    case thinEnv(ThinEnvironment)
    case mgmt(ThinEnvironment)
    case aggregator(GuardicoreAggregator, env: ThinEnvironment)
    case cluster(GuardicoreCluster, env: ThinEnvironment)

    var id: String {
        switch self {
        case .thinEnv(let env):
            return "env-\(env.id.uuidString)"
        case .mgmt(let env):
            return "mgmt-\(env.id.uuidString)"
        case .aggregator(let aggr, let env):
            return "aggr-\(env.id.uuidString)-\(aggr.id.uuidString)"
        case .cluster(let cluster, let env):
            return "cluster-\(env.id.uuidString)-\(cluster.id.uuidString)"
        }
    }
}

struct ConnectionDetailsSheet: View {
    let target: ConnectionTarget

    @EnvironmentObject var thinEnvStore: ThinEnvStore
    @Environment(\.dismiss) var dismiss

    @State private var username: String = ""
    @State private var password: String = ""

    private var title: String { "Connection Details" }

    private var subtitle: String {
        switch target {
        case .thinEnv(let env):
            return "Tester — \(env.host)"
        case .mgmt(let env):
            return "Management — \(env.host) → mgmt"
        case .aggregator(let aggr, let env):
            return "Aggregator — \(env.host) → \(aggr.address)"
        case .cluster(let cluster, let env):
            return "Cluster — \(env.host) → \(cluster.ip)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 12) {
                connectionInfoSection

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption).foregroundColor(.secondary)
                    TextField(ThinEnvironment.defaultUser, text: $username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption).foregroundColor(.secondary)
                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 28)

            Button(action: save) {
                Label("Save", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .frame(width: 380)
        .onAppear { populate() }
    }

    @ViewBuilder
    private var connectionInfoSection: some View {
        switch target {
        case .thinEnv(let env):
            readOnlyRow(label: "Host", value: env.host)
        case .mgmt(let env):
            readOnlyRow(label: "Thin Env", value: env.host)
            readOnlyRow(label: "Management Host", value: ThinEnvironment.mgmtHost)
        case .aggregator(let aggr, let env):
            readOnlyRow(label: "Thin Env", value: env.host)
            readOnlyRow(label: "Aggregator Address", value: aggr.address)
        case .cluster(let cluster, let env):
            readOnlyRow(label: "Thin Env", value: env.host)
            readOnlyRow(label: "Cluster IP", value: cluster.ip)
        }
    }

    private func readOnlyRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption).foregroundColor(.secondary)
            Text(value)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
        }
    }

    private func populate() {
        switch target {
        case .thinEnv(let env):
            username = env.username
            password = env.password
        case .mgmt(let env):
            username = env.mgmtUsername
            password = env.mgmtPassword
        case .aggregator(let aggr, let env):
            username = aggr.username.isEmpty ? env.username : aggr.username
            password = aggr.password.isEmpty ? env.password : aggr.password
        case .cluster(let cluster, let env):
            username = cluster.username.isEmpty ? env.username : cluster.username
            password = cluster.password.isEmpty ? env.password : cluster.password
        }
    }

    private func save() {
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        let trimPass = password.isEmpty ? ThinEnvironment.defaultPassword : password

        switch target {
        case .thinEnv(var env):
            env.username = trimUser
            env.password = trimPass
            thinEnvStore.update(env)

        case .mgmt(var env):
            env.mgmtUsername = trimUser
            env.mgmtPassword = trimPass
            thinEnvStore.update(env)

        case .aggregator(var aggr, let env):
            aggr.username = trimUser
            aggr.password = trimPass
            thinEnvStore.updateAggregator(aggr, inEnvID: env.id)

        case .cluster(var cluster, let env):
            cluster.username = trimUser
            cluster.password = trimPass
            thinEnvStore.updateCluster(cluster, inEnvID: env.id)
        }

        dismiss()
    }
}
