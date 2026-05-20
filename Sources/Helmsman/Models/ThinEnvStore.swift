// ThinEnvStore.swift — Gardicol Connector
// Observable store: loads/saves thin environments to disk.

import Foundation
import SwiftUI

@MainActor
public final class ThinEnvStore: ObservableObject {

    public static let shared = ThinEnvStore()

    @Published public var environments: [ThinEnvironment] = []

    private let url: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
        let base = support.appendingPathComponent("Helmsman")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("thin_environments.json")
        load()
    }

    // MARK: - Persistence

    public func load() {
        environments = (try? JSONDecoder().decode([ThinEnvironment].self,
                                                  from: Data(contentsOf: url))) ?? []
    }

    public func save() {
        try? JSONEncoder().encode(environments).write(to: url, options: .atomic)
    }

    // MARK: - Thin env CRUD

    public func add(_ env: ThinEnvironment) {
        var e = env
        e.sortOrder = environments.count
        environments.append(e)
        save()
    }

    public func delete(id: UUID) {
        environments.removeAll { $0.id == id }
        save()
    }

    public func update(_ env: ThinEnvironment) {
        guard let idx = environments.firstIndex(where: { $0.id == env.id }) else { return }
        environments[idx] = env
        save()
    }

    public func environment(id: UUID) -> ThinEnvironment? {
        environments.first { $0.id == id }
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) {
        environments.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in environments.indices { environments[i].sortOrder = i }
        save()
    }

    // MARK: - Cluster CRUD

    public func addCluster(_ cluster: GuardicoreCluster, toEnvID envID: UUID) {
        guard let idx = environments.firstIndex(where: { $0.id == envID }) else { return }
        environments[idx].clusters.append(cluster)
        save()
    }

    public func deleteCluster(id clusterID: UUID, fromEnvID envID: UUID) {
        guard let idx = environments.firstIndex(where: { $0.id == envID }) else { return }
        environments[idx].clusters.removeAll { $0.id == clusterID }
        save()
    }

    public func updateCluster(_ cluster: GuardicoreCluster, inEnvID envID: UUID) {
        guard let envIdx = environments.firstIndex(where: { $0.id == envID }),
              let clusterIdx = environments[envIdx].clusters.firstIndex(where: { $0.id == cluster.id })
        else { return }
        environments[envIdx].clusters[clusterIdx] = cluster
        save()
    }

    // MARK: - Aggregator CRUD

    public func addAggregator(_ aggregator: GuardicoreAggregator, toEnvID envID: UUID) {
        guard let idx = environments.firstIndex(where: { $0.id == envID }) else { return }
        environments[idx].aggregators.append(aggregator)
        save()
    }

    public func deleteAggregator(id aggregatorID: UUID, fromEnvID envID: UUID) {
        guard let idx = environments.firstIndex(where: { $0.id == envID }) else { return }
        environments[idx].aggregators.removeAll { $0.id == aggregatorID }
        save()
    }

    public func updateAggregator(_ aggregator: GuardicoreAggregator, inEnvID envID: UUID) {
        guard let envIdx = environments.firstIndex(where: { $0.id == envID }),
              let aggrIdx = environments[envIdx].aggregators.firstIndex(where: { $0.id == aggregator.id })
        else { return }
        environments[envIdx].aggregators[aggrIdx] = aggregator
        save()
    }
}
