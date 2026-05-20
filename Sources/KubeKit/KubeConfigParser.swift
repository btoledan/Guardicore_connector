// KubeConfigParser.swift — KubeKit
// Parses ~/.kube/config into KubeContext objects.
// Strategy: shell out to `kubectl config view --output=json` if kubectl/oc
// is available; fall back to a minimal YAML line-by-line parser otherwise.

import Foundation

public enum KubeConfigParser {

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case noKubeConfig
        case parseFailure(String)
        case processError(String)

        public var errorDescription: String? {
            switch self {
            case .noKubeConfig:           return "No ~/.kube/config found."
            case .parseFailure(let msg):  return "Could not parse kube config: \(msg)"
            case .processError(let msg):  return "kubectl/oc error: \(msg)"
            }
        }
    }

    // MARK: - Public entry point

    /// Returns all contexts from ~/.kube/config (and any files in KUBECONFIG env var).
    public static func load() async throws -> [KubeContext] {
        // 1. Try kubectl/oc JSON output (most reliable)
        if let contexts = try? await loadViaKubectl() { return contexts }
        // 2. Fall back to direct YAML parsing
        return try loadFromFile()
    }

    // MARK: - kubectl / oc JSON path

    private static func loadViaKubectl() async throws -> [KubeContext] {
        let kubectlPath = which("kubectl") ?? which("oc")
        guard let binPath = kubectlPath else {
            throw Error.processError("kubectl / oc not found in PATH")
        }

        let (output, _) = try await runProcess(
            executable: binPath,
            args: ["config", "view", "--output=json", "--merge=true"]
        )

        guard let data = output.data(using: .utf8) else {
            throw Error.parseFailure("Empty output from kubectl config view")
        }

        let raw = try JSONDecoder().decode(RawKubeConfig.self, from: data)
        return buildContexts(from: raw)
    }

    // MARK: - Direct YAML path

    private static func loadFromFile() throws -> [KubeContext] {
        let kubeConfigURL = defaultKubeConfigURL()
        guard FileManager.default.fileExists(atPath: kubeConfigURL.path) else {
            return []  // Not an error — user may not use kube
        }

        let yaml: String
        do {
            yaml = try String(contentsOf: kubeConfigURL, encoding: .utf8)
        } catch {
            throw Error.parseFailure(error.localizedDescription)
        }

        // Minimal YAML parser for the kube config structure.
        // Handles the subset: top-level keys, list items (- ), and nested keys.
        return try parseYAML(yaml)
    }

    // MARK: - Context assembly

    private static func buildContexts(from raw: RawKubeConfig) -> [KubeContext] {
        let clusterMap = Dictionary(
            raw.clusters.map { ($0.name, $0.cluster) },
            uniquingKeysWith: { first, _ in first }
        )

        return raw.contexts.compactMap { named -> KubeContext? in
            guard let cluster = clusterMap[named.context.cluster] else { return nil }
            let ns = named.context.namespace ?? "default"
            let isOS = isOpenShift(serverURL: cluster.server)
            return KubeContext(
                contextName:      named.name,
                clusterName:      named.context.cluster,
                serverURL:        cluster.server,
                user:             named.context.user,
                pinnedNamespace:  ns,
                isOpenShift:      isOS
            )
        }
    }

    private static func isOpenShift(serverURL: String) -> Bool {
        // Heuristic: OpenShift API server typically uses port 6443
        serverURL.contains(":6443") || serverURL.lowercased().contains("openshift")
    }

    // MARK: - Minimal YAML parser

    private struct ClusterInfo { var server: String }

    private static func parseYAML(_ yaml: String) throws -> [KubeContext] {
        // This parser handles the specific kube config YAML structure.
        // It is NOT a general YAML parser.
        var clusters:  [String: ClusterInfo] = [:]
        var contexts:  [(name: String, cluster: String, user: String, namespace: String)] = []
        var currentSection:  String = ""
        var currentContext:  String = ""
        var currentListItem: [String: String] = [:]
        var inClusterBlock = false
        var inContextBlock = false

        for rawLine in yaml.components(separatedBy: .newlines) {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let indent = line.prefix(while: { $0 == " " }).count

            // Top-level section headers
            if indent == 0 {
                if trimmed.hasPrefix("clusters:") { currentSection = "clusters"; inClusterBlock = false; inContextBlock = false }
                else if trimmed.hasPrefix("contexts:") { currentSection = "contexts"; inClusterBlock = false; inContextBlock = false }
                else if trimmed.hasPrefix("current-context:") {
                    currentContext = trimmed.replacingOccurrences(of: "current-context:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    currentSection = ""
                } else {
                    currentSection = ""
                }
                // Commit any pending list item
                commitListItem(&currentListItem, section: currentSection,
                               clusters: &clusters, contexts: &contexts)
                currentListItem = [:]
                continue
            }

            // New list item
            if trimmed.hasPrefix("- ") {
                commitListItem(&currentListItem, section: currentSection,
                               clusters: &clusters, contexts: &contexts)
                currentListItem = [:]
                let rest = String(trimmed.dropFirst(2))
                if let (k, v) = splitKeyValue(rest) {
                    currentListItem[k] = v
                }
                inClusterBlock = false
                inContextBlock = false
                continue
            }

            // Key: value within current list item
            if let (k, v) = splitKeyValue(trimmed) {
                switch k {
                case "name":    currentListItem["name"]      = v
                case "cluster": inClusterBlock = true; inContextBlock = false
                case "context": inContextBlock = true; inClusterBlock = false
                case "server":  if inClusterBlock { currentListItem["server"] = v }
                case "namespace": if inContextBlock { currentListItem["namespace"] = v }
                case "user":    if inContextBlock { currentListItem["contextUser"] = v }
                default: break
                }
            }
        }
        commitListItem(&currentListItem, section: currentSection,
                       clusters: &clusters, contexts: &contexts)

        return contexts.compactMap { ctx -> KubeContext? in
            guard let cluster = clusters[ctx.cluster] else { return nil }
            return KubeContext(
                contextName:     ctx.name,
                clusterName:     ctx.cluster,
                serverURL:       cluster.server,
                user:            ctx.user,
                pinnedNamespace: ctx.namespace.isEmpty ? "default" : ctx.namespace,
                isOpenShift:     isOpenShift(serverURL: cluster.server)
            )
        }
    }

    private static func commitListItem(
        _ item: inout [String: String],
        section: String,
        clusters: inout [String: ClusterInfo],
        contexts: inout [(name: String, cluster: String, user: String, namespace: String)]
    ) {
        guard !item.isEmpty, let name = item["name"] else { return }
        switch section {
        case "clusters":
            if let server = item["server"] {
                clusters[name] = ClusterInfo(server: server)
            }
        case "contexts":
            contexts.append((
                name:      name,
                cluster:   item["cluster"] ?? "",
                user:      item["contextUser"] ?? "",
                namespace: item["namespace"] ?? "default"
            ))
        default: break
        }
    }

    private static func splitKeyValue(_ s: String) -> (String, String)? {
        guard let colonIdx = s.firstIndex(of: ":") else { return nil }
        let key = String(s[s.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rest = String(s[s.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        let value = rest.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return key.isEmpty ? nil : (key, value)
    }

    // MARK: - Helpers

    private static func defaultKubeConfigURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".kube/config")
    }

    private static func which(_ command: String) -> String? {
        let paths = ProcessInfo.processInfo.environment["PATH"]?
            .components(separatedBy: ":") ?? ["/usr/local/bin", "/usr/bin", "/opt/homebrew/bin"]
        return paths
            .map { ($0 as NSString).appendingPathComponent(command) }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func runProcess(
        executable: String,
        args: [String]
    ) async throws -> (stdout: String, exitCode: Int32) {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError  = errPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: Error.processError(error.localizedDescription))
                return
            }

            process.terminationHandler = { p in
                let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""
                continuation.resume(returning: (stdout: output, exitCode: p.terminationStatus))
            }
        }
    }
}
