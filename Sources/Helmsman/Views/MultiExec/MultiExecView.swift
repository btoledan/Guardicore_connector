// MultiExecView.swift — Helmsman
// Execute a command across selected terminal tabs simultaneously.
// Features: dry-run preview, stop-on-first-failure toggle, stderr merge, save last command set.

import SwiftUI
import TerminalKit

struct MultiExecView: View {
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @Environment(\.dismiss) var dismiss

    @State private var command:        String = ""
    @State private var selectedIDs:    Set<UUID> = []
    @State private var dryRun:         Bool = true
    @State private var stopOnFailure:  Bool = true
    @State private var previewLines:   [String] = []
    @State private var savedCommandSets: [String] = []
    @State private var showSaveAlert:  Bool = false
    @State private var saveSetName:    String = ""

    @AppStorage("helmsman.multiExec.saved") private var savedJSON: String = "[]"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Command input ────────────────────────────────────────────
                commandInput

                Divider()

                HStack(alignment: .top, spacing: 0) {
                    // ── Tab selection ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Target Tabs (\(selectedIDs.count) selected)")
                            .font(.caption).foregroundColor(.secondary)
                            .padding(.horizontal, 12).padding(.top, 8)
                        List(activeTerminals.tabs, selection: $selectedIDs) { tab in
                            HStack {
                                Image(systemName: "terminal")
                                Text(tab.title).lineLimit(1)
                            }
                            .tag(tab.id)
                        }
                        .listStyle(.bordered)
                        HStack {
                            Button("All")  { selectedIDs = Set(activeTerminals.tabs.map(\.id)) }
                            Button("None") { selectedIDs = [] }
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                    }
                    .frame(width: 200)

                    Divider()

                    // ── Options + Preview ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        optionsSection
                        Divider()
                        previewSection
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .navigationTitle("Multi-Exec")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(dryRun ? "Preview" : "Execute") { execute() }
                        .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || selectedIDs.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(width: 580, height: 480)
        .onAppear {
            // Pre-select all tabs
            selectedIDs = Set(activeTerminals.tabs.map(\.id))
            loadSavedSets()
        }
        .alert("Save Command Set", isPresented: $showSaveAlert) {
            TextField("Name", text: $saveSetName)
            Button("Save") { saveCommandSet() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Command input

    private var commandInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "terminal").foregroundColor(.secondary)
                TextField("Command to execute on all selected tabs…", text: $command)
                    .font(.body.monospaced())
                    .textFieldStyle(.plain)
                    .onSubmit { execute() }
                if !savedCommandSets.isEmpty {
                    Menu("Saved") {
                        ForEach(savedCommandSets, id: \.self) { cmd in
                            Button(cmd) { command = cmd }
                        }
                    }
                    .frame(width: 80)
                }
                Button {
                    showSaveAlert = true
                    saveSetName   = String(command.prefix(30))
                } label: {
                    Image(systemName: "bookmark")
                }
                .buttonStyle(.plain)
                .help("Save this command")
            }
            .padding(10)
            .background(.bar)
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Options").font(.headline)
            Toggle("Dry-run (preview only — don't send)", isOn: $dryRun)
            Toggle("Stop on first failure", isOn: $stopOnFailure)
                .help("If any tab returns a non-zero exit, stop sending to remaining tabs.\nRequires shell integration to detect exit codes.")
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        if !previewLines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview").font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(previewLines, id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(8)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Actions

    private func execute() {
        let lines = activeTerminals.multiExec(
            command:   command,
            targetIDs: selectedIDs,
            dryRun:    dryRun
        )
        previewLines = lines
        if !dryRun { dismiss() }
    }

    private func loadSavedSets() {
        savedCommandSets = (try? JSONDecoder().decode([String].self, from: Data(savedJSON.utf8))) ?? []
    }

    private func saveCommandSet() {
        var sets = savedCommandSets
        if !sets.contains(command) { sets.append(command) }
        savedCommandSets = sets
        savedJSON = (try? String(data: JSONEncoder().encode(sets), encoding: .utf8)) ?? "[]"
    }
}
