// KubeContextDockView.swift — Helmsman
// Bottom dock: pinned kube contexts, namespace picker, and snippet runner.

import SwiftUI
import KubeKit

struct KubeContextDockView: View {
    @EnvironmentObject var kubeStore:       KubeStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore

    @State private var snippetQuery:  String = ""
    @State private var selectedSnippet: Snippet?
    @State private var renderedCommand: String = ""
    @State private var podName:         String = ""

    var body: some View {
        HStack(spacing: 0) {
            // ── Context list ─────────────────────────────────────────────────
            contextList

            Divider()

            // ── Snippet runner ───────────────────────────────────────────────
            snippetRunner
        }
        .background(.bar)
    }

    // MARK: - Context list

    private var contextList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kube Contexts").font(.caption2).foregroundColor(.secondary)
                .padding(.horizontal, 10).padding(.top, 8)

            List(kubeStore.contexts) { ctx in
                HStack {
                    Image(systemName: ctx.isOpenShift ? "server.rack" : "cloud")
                        .font(.caption)
                        .foregroundColor(ctx.isOpenShift ? .red : .blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ctx.displayName).font(.caption).lineLimit(1)
                        Text(ctx.pinnedNamespace).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if kubeStore.pinnedContext?.id == ctx.id {
                        Image(systemName: "pin.fill").font(.caption2).foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { kubeStore.pin(ctx) }
            }
            .listStyle(.plain)
        }
        .frame(width: 200)
    }

    // MARK: - Snippet runner

    private var snippetRunner: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context + namespace header
            if let ctx = kubeStore.pinnedContext {
                HStack {
                    Label(ctx.displayName, systemImage: ctx.isOpenShift ? "server.rack" : "cloud")
                        .font(.caption).foregroundColor(.secondary)
                    Text("›").foregroundColor(.secondary)
                    Text(ctx.pinnedNamespace).font(.caption.bold())
                    Spacer()
                    TextField("Pod name (optional)", text: $podName)
                        .font(.caption.monospaced())
                        .frame(width: 160)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                // Snippet list
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Filter snippets…", text: $snippetQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    List(filteredSnippets) { snippet in
                        Text(snippet.label)
                            .font(.caption)
                            .onTapGesture { select(snippet) }
                            .foregroundColor(selectedSnippet?.id == snippet.id ? .accentColor : .primary)
                    }
                    .listStyle(.plain)
                    .frame(height: 100)
                }
                .frame(width: 220)

                // Rendered command
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command").font(.caption2).foregroundColor(.secondary)
                    Text(renderedCommand.isEmpty ? "Select a snippet →" : renderedCommand)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                    HStack {
                        Button("Run in Active Tab") { runInActiveTab() }
                            .buttonStyle(.borderedProminent)
                            .disabled(renderedCommand.isEmpty)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(renderedCommand, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .help("Copy command")
                        .disabled(renderedCommand.isEmpty)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var filteredSnippets: [Snippet] {
        SnippetLibrary.snippets(matching: snippetQuery)
    }

    private func select(_ snippet: Snippet) {
        selectedSnippet = snippet
        guard let ctx = kubeStore.pinnedContext else {
            renderedCommand = snippet.rendered()
            return
        }
        renderedCommand = snippet.rendered(
            context:   ctx.contextName,
            namespace: ctx.pinnedNamespace,
            pod:       podName,
            cliTool:   ctx.cliTool
        )
    }

    private func runInActiveTab() {
        activeTerminals.activeTab?.run(renderedCommand)
    }
}
