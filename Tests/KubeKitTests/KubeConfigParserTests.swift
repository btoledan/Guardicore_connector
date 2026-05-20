// KubeConfigParserTests.swift — KubeKitTests

import XCTest
@testable import KubeKit

final class KubeConfigParserTests: XCTestCase {

    // MARK: - Snippet library

    func test_snippetLibrary_hasBuiltIns() {
        XCTAssertFalse(SnippetLibrary.builtIn.isEmpty)
    }

    func test_snippetLibrary_filterByTool() {
        let ocSnippets = SnippetLibrary.snippets(for: .oc)
        XCTAssertFalse(ocSnippets.isEmpty)
        XCTAssertTrue(ocSnippets.allSatisfy { $0.tool == .oc })
    }

    func test_snippetLibrary_searchReturnsRelevantResults() {
        let results = SnippetLibrary.snippets(matching: "pod")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy {
            $0.label.lowercased().contains("pod") || $0.command.lowercased().contains("pod")
        })
    }

    func test_snippetLibrary_emptyQuery_returnsAll() {
        XCTAssertEqual(SnippetLibrary.snippets(matching: "").count,
                       SnippetLibrary.builtIn.count)
    }

    // MARK: - Snippet rendering

    func test_snippet_rendered_substitutesNamespace() {
        let snip = Snippet(label: "test", command: "kubectl get pods {{NAMESPACE}}", category: .pods, tool: .kubectl)
        let rendered = snip.rendered(namespace: "my-ns")
        XCTAssert(rendered.contains("-n my-ns"))
        XCTAssertFalse(rendered.contains("{{NAMESPACE}}"))
    }

    func test_snippet_rendered_substitutesContext() {
        let snip = Snippet(label: "test", command: "kubectl get pods {{CONTEXT}}", category: .pods, tool: .kubectl)
        let rendered = snip.rendered(context: "my-ctx")
        XCTAssert(rendered.contains("--context=my-ctx"))
    }

    func test_snippet_rendered_emptyNamespace_noFlag() {
        let snip = Snippet(label: "test", command: "kubectl get pods {{NAMESPACE}}", category: .pods, tool: .kubectl)
        let rendered = snip.rendered(namespace: "")
        XCTAssertFalse(rendered.contains("-n"))
        XCTAssertFalse(rendered.contains("{{NAMESPACE}}"))
    }

    func test_snippet_rendered_cliToolOverride() {
        let snip = Snippet(label: "test", command: "{{TOOL}} get pods", category: .pods, tool: .kubectl)
        let rendered = snip.rendered(cliTool: "oc")
        XCTAssert(rendered.hasPrefix("oc"))
    }

    func test_snippet_rendered_doubleSpacesCollapsed() {
        let snip = Snippet(label: "test", command: "{{TOOL}} get pods {{NAMESPACE}} {{CONTEXT}}", category: .pods, tool: .kubectl)
        let rendered = snip.rendered()
        XCTAssertFalse(rendered.contains("  "), "Double spaces should be collapsed")
    }

    // MARK: - KubeContext

    func test_kubeContext_displayName_trimsUserSuffix() {
        let ctx = KubeContext(
            contextName:     "openshift-prod/admin",
            clusterName:     "openshift-prod",
            serverURL:       "https://api.example.com:6443",
            user:            "admin",
            pinnedNamespace: "default",
            isOpenShift:     true
        )
        XCTAssertEqual(ctx.displayName, "openshift-prod")
    }

    func test_kubeContext_cliTool_openshift_isOc() {
        let ctx = KubeContext(contextName: "c", clusterName: "c", serverURL: "https://api.example.com:6443",
                              user: "u", pinnedNamespace: "default", isOpenShift: true)
        XCTAssertEqual(ctx.cliTool, "oc")
    }

    func test_kubeContext_cliTool_k8s_isKubectl() {
        let ctx = KubeContext(contextName: "c", clusterName: "c", serverURL: "https://k8s.example.com:6443",
                              user: "u", pinnedNamespace: "default", isOpenShift: false)
        XCTAssertEqual(ctx.cliTool, "kubectl")
    }

    // MARK: - JSON decoding (RawKubeConfig)

    func test_rawKubeConfig_decodesFixtureJSON() throws {
        // Load the fixture YAML via kubectl if available, else skip
        guard let kubectlPath = findExecutable("kubectl") ?? findExecutable("oc") else {
            throw XCTSkip("kubectl/oc not available in test environment")
        }

        let fixtureURL = Bundle(for: type(of: self)).resourceURL!
            .appendingPathComponent("Fixtures/kube_config")

        let p = Process()
        p.executableURL = URL(fileURLWithPath: kubectlPath)
        p.arguments = ["config", "view", "--kubeconfig=\(fixtureURL.path)", "--output=json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw XCTSkip("kubectl config view failed — skipping JSON decode test")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let raw  = try JSONDecoder().decode(RawKubeConfig.self, from: data)
        XCTAssertFalse(raw.clusters.isEmpty)
        XCTAssertFalse(raw.contexts.isEmpty)
    }

    // MARK: - Namespace pin

    func test_namespacePin_defaultsToDefault() {
        let pin = NamespacePin(contextName: "ctx", namespace: "")
        XCTAssertEqual(pin.namespace, "default")
    }

    func test_namespacePin_labelFallsBackToNamespace() {
        let pin = NamespacePin(contextName: "ctx", namespace: "my-ns")
        XCTAssertEqual(pin.label, "my-ns")
    }

    // MARK: - Helper

    private func findExecutable(_ name: String) -> String? {
        let paths = ProcessInfo.processInfo.environment["PATH"]?
            .components(separatedBy: ":") ?? []
        return paths
            .map { ($0 as NSString).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
