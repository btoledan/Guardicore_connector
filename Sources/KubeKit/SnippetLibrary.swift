// SnippetLibrary.swift — KubeKit
// Pre-built oc / kubectl / helm snippet templates with namespace injection.

import Foundation

// MARK: - Snippet

public struct Snippet: Identifiable, Codable, Hashable, Sendable {
    public var id:       UUID
    public var label:    String
    public var command:  String   // may contain {{NAMESPACE}}, {{CONTEXT}}, {{POD}} tokens
    public var category: Category
    public var tool:     Tool

    public enum Category: String, Codable, CaseIterable, Sendable {
        case pods       = "Pods"
        case logs       = "Logs"
        case exec       = "Exec / Shell"
        case resources  = "Resources"
        case config     = "Config"
        case helm       = "Helm"
        case networking = "Networking"
    }

    public enum Tool: String, Codable, CaseIterable, Sendable {
        case oc      = "oc"
        case kubectl = "kubectl"
        case helm    = "helm"
    }

    public init(label: String, command: String, category: Category, tool: Tool) {
        self.id       = UUID()
        self.label    = label
        self.command  = command
        self.category = category
        self.tool     = tool
    }

    // MARK: Rendering

    /// Substitutes template tokens with real values.
    /// Tokens: {{NAMESPACE}}, {{CONTEXT}}, {{POD}}, {{CONTAINER}}, {{SELECTOR}}
    public func rendered(
        context:   String = "",
        namespace: String = "",
        pod:       String = "",
        container: String = "",
        selector:  String = "",
        cliTool:   String? = nil      // override tool (e.g., use "oc" in OpenShift contexts)
    ) -> String {
        let base = cliTool ?? tool.rawValue
        var cmd = command
            .replacingOccurrences(of: "{{TOOL}}",      with: base)
            .replacingOccurrences(of: "{{CONTEXT}}",   with: context.isEmpty   ? "" : "--context=\(context)")
            .replacingOccurrences(of: "{{NAMESPACE}}", with: namespace.isEmpty ? "" : "-n \(namespace)")
            .replacingOccurrences(of: "{{POD}}",       with: pod)
            .replacingOccurrences(of: "{{CONTAINER}}", with: container.isEmpty ? "" : "-c \(container)")
            .replacingOccurrences(of: "{{SELECTOR}}",  with: selector)

        // Collapse double-spaces introduced by empty substitutions
        while cmd.contains("  ") { cmd = cmd.replacingOccurrences(of: "  ", with: " ") }
        return cmd.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Library

public enum SnippetLibrary {

    // MARK: Built-in snippets

    public static let builtIn: [Snippet] = pods + logs + execShell + resources + helmSnippets + networking

    // MARK: Pods

    private static let pods: [Snippet] = [
        .init(label: "List pods",
              command: "{{TOOL}} get pods {{NAMESPACE}} {{CONTEXT}} -o wide",
              category: .pods, tool: .kubectl),
        .init(label: "List pods (watch)",
              command: "{{TOOL}} get pods {{NAMESPACE}} {{CONTEXT}} -w",
              category: .pods, tool: .kubectl),
        .init(label: "Describe pod",
              command: "{{TOOL}} describe pod {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .pods, tool: .kubectl),
        .init(label: "Delete pod (graceful)",
              command: "{{TOOL}} delete pod {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .pods, tool: .kubectl),
        .init(label: "Delete pod (force)",
              command: "{{TOOL}} delete pod {{POD}} {{NAMESPACE}} {{CONTEXT}} --grace-period=0 --force",
              category: .pods, tool: .kubectl),
        .init(label: "Get pod YAML",
              command: "{{TOOL}} get pod {{POD}} {{NAMESPACE}} {{CONTEXT}} -o yaml",
              category: .pods, tool: .kubectl),
        .init(label: "List all pods (all namespaces)",
              command: "{{TOOL}} get pods --all-namespaces {{CONTEXT}} -o wide",
              category: .pods, tool: .kubectl),
        // OpenShift-specific
        .init(label: "oc get pods",
              command: "oc get pods {{NAMESPACE}} {{CONTEXT}} -o wide",
              category: .pods, tool: .oc),
        .init(label: "oc rsh into pod",
              command: "oc rsh {{NAMESPACE}} {{POD}}",
              category: .pods, tool: .oc),
    ]

    // MARK: Logs

    private static let logs: [Snippet] = [
        .init(label: "Tail logs",
              command: "{{TOOL}} logs -f {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}}",
              category: .logs, tool: .kubectl),
        .init(label: "Last 100 lines",
              command: "{{TOOL}} logs --tail=100 {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}}",
              category: .logs, tool: .kubectl),
        .init(label: "Logs since 1h",
              command: "{{TOOL}} logs --since=1h {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}}",
              category: .logs, tool: .kubectl),
        .init(label: "Previous container logs",
              command: "{{TOOL}} logs -p {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}}",
              category: .logs, tool: .kubectl),
        .init(label: "All container logs (label selector)",
              command: "{{TOOL}} logs -l {{SELECTOR}} {{NAMESPACE}} {{CONTEXT}} --all-containers --prefix",
              category: .logs, tool: .kubectl),
    ]

    // MARK: Exec / Shell

    private static let execShell: [Snippet] = [
        .init(label: "Exec bash in pod",
              command: "{{TOOL}} exec -it {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}} -- /bin/bash",
              category: .exec, tool: .kubectl),
        .init(label: "Exec sh in pod",
              command: "{{TOOL}} exec -it {{POD}} {{NAMESPACE}} {{CONTEXT}} {{CONTAINER}} -- /bin/sh",
              category: .exec, tool: .kubectl),
        .init(label: "Copy file from pod",
              command: "{{TOOL}} cp {{NAMESPACE#}} {{POD}}:/remote/path ./local-path",
              category: .exec, tool: .kubectl),
        .init(label: "oc exec bash",
              command: "oc exec -it {{POD}} {{NAMESPACE}} -- /bin/bash",
              category: .exec, tool: .oc),
    ]

    // MARK: Resources

    private static let resources: [Snippet] = [
        .init(label: "Get deployments",
              command: "{{TOOL}} get deployments {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Get services",
              command: "{{TOOL}} get services {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Get configmaps",
              command: "{{TOOL}} get configmaps {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Get secrets",
              command: "{{TOOL}} get secrets {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Get events (sorted)",
              command: "{{TOOL}} get events {{NAMESPACE}} {{CONTEXT}} --sort-by=.lastTimestamp",
              category: .resources, tool: .kubectl),
        .init(label: "Rollout status",
              command: "{{TOOL}} rollout status deployment/{{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Rollout restart",
              command: "{{TOOL}} rollout restart deployment/{{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        .init(label: "Get nodes",
              command: "{{TOOL}} get nodes -o wide {{CONTEXT}}",
              category: .resources, tool: .kubectl),
        // OpenShift-specific
        .init(label: "oc get routes",
              command: "oc get routes {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .oc),
        .init(label: "oc get imagestreams",
              command: "oc get is {{NAMESPACE}} {{CONTEXT}}",
              category: .resources, tool: .oc),
    ]

    // MARK: Helm

    private static let helmSnippets: [Snippet] = [
        .init(label: "helm list",
              command: "helm list {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm list (all namespaces)",
              command: "helm list --all-namespaces {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm status",
              command: "helm status {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm history",
              command: "helm history {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm rollback (previous)",
              command: "helm rollback {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm get values",
              command: "helm get values {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
        .init(label: "helm get manifest",
              command: "helm get manifest {{POD}} {{NAMESPACE}} {{CONTEXT}}",
              category: .helm, tool: .helm),
    ]

    // MARK: Networking

    private static let networking: [Snippet] = [
        .init(label: "Port-forward to pod",
              command: "{{TOOL}} port-forward pod/{{POD}} 8080:8080 {{NAMESPACE}} {{CONTEXT}}",
              category: .networking, tool: .kubectl),
        .init(label: "Port-forward to service",
              command: "{{TOOL}} port-forward svc/{{POD}} 8080:80 {{NAMESPACE}} {{CONTEXT}}",
              category: .networking, tool: .kubectl),
    ]

    // MARK: Filtering

    public static func snippets(for tool: Snippet.Tool) -> [Snippet] {
        builtIn.filter { $0.tool == tool }
    }

    public static func snippets(category: Snippet.Category) -> [Snippet] {
        builtIn.filter { $0.category == category }
    }

    public static func snippets(matching query: String) -> [Snippet] {
        guard !query.isEmpty else { return builtIn }
        let q = query.lowercased()
        return builtIn.filter {
            $0.label.lowercased().contains(q) || $0.command.lowercased().contains(q)
        }
    }
}
