# Graph Report - .  (2026-06-09)

## Corpus Check
- Corpus is ~44,801 words - fits in a single context window. You may not need a graph.

## Summary
- 1115 nodes · 1974 edges · 68 communities (59 shown, 9 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 44 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_LocalProcessViewRepresentable  NetworkS|LocalProcessViewRepresentable / NetworkS]]
- [[_COMMUNITY_ThinEnvRow  PolicyDigestionView|ThinEnvRow / PolicyDigestionView]]
- [[_COMMUNITY_SnippetLibrary  WorkspaceProfile|SnippetLibrary / WorkspaceProfile]]
- [[_COMMUNITY_KubeConfigParser  TouchIDAuth|KubeConfigParser / TouchIDAuth]]
- [[_COMMUNITY_SessionStore  AppDelegate|SessionStore / AppDelegate]]
- [[_COMMUNITY_Keychain  NewSessionSheet|Keychain / NewSessionSheet]]
- [[_COMMUNITY_ClusterOverviewView|ClusterOverviewView]]
- [[_COMMUNITY_ClusterViewModel  ClusterViewComponents|ClusterViewModel / ClusterViewComponents]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_ClusterSnapshot|ClusterSnapshot]]
- [[_COMMUNITY_SFTPPaneView  NetworkScannerView|SFTPPaneView / NetworkScannerView]]
- [[_COMMUNITY_ActiveTerminalsStore|ActiveTerminalsStore]]
- [[_COMMUNITY_ThinEnvironment  SidebarView|ThinEnvironment / SidebarView]]
- [[_COMMUNITY_TerminalSession|TerminalSession]]
- [[_COMMUNITY_SSHConfigParser|SSHConfigParser]]
- [[_COMMUNITY_ScanResult|ScanResult]]
- [[_COMMUNITY_ThinEnvironment|ThinEnvironment]]
- [[_COMMUNITY_KubeContext|KubeContext]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_ThinEnvStore|ThinEnvStore]]
- [[_COMMUNITY_ProxyJumpChain|ProxyJumpChain]]
- [[_COMMUNITY_ClusterTopologyView|ClusterTopologyView]]
- [[_COMMUNITY_SSHSessionDescriptor  KubeContext|SSHSessionDescriptor / KubeContext]]
- [[_COMMUNITY_ProxyJumpTests|ProxyJumpTests]]
- [[_COMMUNITY_KubeConfigParserTests|KubeConfigParserTests]]
- [[_COMMUNITY_TranscriptWriter|TranscriptWriter]]
- [[_COMMUNITY_Session|Session]]
- [[_COMMUNITY_ClusterSnapshot|ClusterSnapshot]]
- [[_COMMUNITY_ClusterViewComponents  ClusterRawView|ClusterViewComponents / ClusterRawView]]
- [[_COMMUNITY_SSHConfigParserTests|SSHConfigParserTests]]
- [[_COMMUNITY_ProxyJumpComposerView|ProxyJumpComposerView]]
- [[_COMMUNITY_SSHSessionDescriptor|SSHSessionDescriptor]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_SSHSessionDescriptor|SSHSessionDescriptor]]
- [[_COMMUNITY_ConnectionDetailsSheet|ConnectionDetailsSheet]]
- [[_COMMUNITY_MultiExecView|MultiExecView]]
- [[_COMMUNITY_GuardicoreStatusView|GuardicoreStatusView]]
- [[_COMMUNITY_TunnelManagerView|TunnelManagerView]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_TerminalTabsView|TerminalTabsView]]
- [[_COMMUNITY_AddAggregatorSheet|AddAggregatorSheet]]
- [[_COMMUNITY_AddClusterSheet|AddClusterSheet]]
- [[_COMMUNITY_ClusterControlPanelView|ClusterControlPanelView]]
- [[_COMMUNITY_KubeContextDockView|KubeContextDockView]]
- [[_COMMUNITY_SessionRowView|SessionRowView]]
- [[_COMMUNITY_AddThinEnvSheet|AddThinEnvSheet]]
- [[_COMMUNITY_ClusterCommandsView|ClusterCommandsView]]
- [[_COMMUNITY_ClusterSnapshotExport|ClusterSnapshotExport]]
- [[_COMMUNITY_SSHDoubleHop|SSHDoubleHop]]
- [[_COMMUNITY_RootContentView|RootContentView]]
- [[_COMMUNITY_TerminalPaneView|TerminalPaneView]]
- [[_COMMUNITY_ClusterCustomCommandsStorage|ClusterCustomCommandsStorage]]
- [[_COMMUNITY_ClusterPoliciesView|ClusterPoliciesView]]
- [[_COMMUNITY_SSHToolLocator|SSHToolLocator]]
- [[_COMMUNITY_HelmsmanApp|HelmsmanApp]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_SettingsView|SettingsView]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_PreToolUse|PreToolUse]]
- [[_COMMUNITY_KubeJSONParser|KubeJSONParser]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]

## God Nodes (most connected - your core abstractions)
1. `ThinEnvRow` - 23 edges
2. `String` - 22 edges
3. `ProxyJumpTests` - 21 edges
4. `TerminalSession` - 20 edges
5. `ActiveTerminalsStore` - 19 edges
6. `ThinEnvStore` - 18 edges
7. `ThinEnvironment` - 18 edges
8. `WellKnownPort` - 18 edges
9. `KubeConfigParserTests` - 18 edges
10. `Session` - 16 edges

## Surprising Connections (you probably didn't know these)
- `parseAgentRevisionLogs()` --calls--> `Result`  [INFERRED]
  test_parser.swift → Sources/Helmsman/Views/Terminal/SFTPPaneView.swift
- `TranscriptTerminalView` --inherits--> `LocalProcessTerminalView`  [EXTRACTED]
  Sources/TerminalKit/LocalProcessViewRepresentable.swift → Sources/TerminalKit/TerminalSession.swift
- `AppCommands` --references--> `commands`  [EXTRACTED]
  Sources/Helmsman/App/AppCommands.swift → Sources/Helmsman/Views/ThinEnv/ClusterViewComponents.swift

## Import Cycles
- None detected.

## Communities (68 total, 9 thin omitted)

### Community 0 - "LocalProcessViewRepresentable / NetworkS"
Cohesion: 0.07
Nodes (30): Context, Coordinator, Double, LocalProcess, NetworkScanner, Never, NSViewRepresentable, ScanState (+22 more)

### Community 1 - "ThinEnvRow / PolicyDigestionView"
Cohesion: 0.07
Nodes (32): ConnectionTarget, accent, AppTheme, semantic, surface, text, CalicoPolicy, ClusterSnapshot (+24 more)

### Community 2 - "SnippetLibrary / WorkspaceProfile"
Cohesion: 0.06
Nodes (35): CaseIterable, Category, Kind, Category, config, exec, helm, logs (+27 more)

### Community 3 - "KubeConfigParser / TouchIDAuth"
Cohesion: 0.09
Nodes (26): ClusterInfo, Error, noKubeConfig, parseFailure, processError, KubeConfigParser, LocalizedError, RawKubeConfig (+18 more)

### Community 4 - "SessionStore / AppDelegate"
Cohesion: 0.07
Nodes (20): AppDelegate, Notification.Name, SessionStore, SpotlightIndexer, Notification, NSApplication, NSApplicationDelegate, NSObject (+12 more)

### Community 5 - "Keychain / NewSessionSheet"
Cohesion: 0.08
Nodes (27): CredentialKind, Error, Field, OSStatus, Field, host, password, username (+19 more)

### Community 6 - "ClusterOverviewView"
Cohesion: 0.11
Nodes (30): Content, Bool, CalicoPolicy, ClusterHealthStatus, ClusterPod, ClusterSnapshot, Color, GuardicoreAgent (+22 more)

### Community 7 - "ClusterViewModel / ClusterViewComponents"
Cohesion: 0.10
Nodes (23): AppCommands, ClusterShellRunner, ClusterViewModel, FetchResult, ActiveTerminalsStore, SessionStore, Bool, ClusterSnapshot (+15 more)

### Community 8 - "KubeJSONParser"
Cohesion: 0.11
Nodes (32): Decodable, KubeCalicoPolicyItem, KubeCalicoRule, KubeContainerStatus, KubeDaemonSetItem, KubeDeploymentItem, KubeDSStatus, KubeNodeItem (+24 more)

### Community 9 - "ClusterSnapshot"
Cohesion: 0.16
Nodes (18): GuardicoreInventoryPod, Identifiable, AgentRevEntry, CalicoPolicy, ClusterNode, ClusterPod, ClusterSnapshotParser, GuardicoreAgent (+10 more)

### Community 10 - "SFTPPaneView / NetworkScannerView"
Cohesion: 0.09
Nodes (24): NetworkScannerView, Process, RemoteItem, Result, SFTPCommandError, ActiveTerminalsStore, Int, ScanResult (+16 more)

### Community 11 - "ActiveTerminalsStore"
Cohesion: 0.10
Nodes (11): ActiveTerminalsStore, KubeStore, ObservableObject, Bool, KubeContext, Session, Set, String (+3 more)

### Community 12 - "ThinEnvironment / SidebarView"
Cohesion: 0.07
Nodes (24): CodingKeys, aggregators, clusters, envNumber, id, label, mgmtPassword, mgmtUsername (+16 more)

### Community 13 - "TerminalSession"
Cohesion: 0.11
Nodes (17): AnySessionSpec, ArraySlice, Int, Int32, LocalProcessTerminalView, String, UInt8, URL (+9 more)

### Community 14 - "SSHConfigParser"
Cohesion: 0.16
Nodes (14): Equatable, Int, String, URL, Block, Error, readError, writeError (+6 more)

### Community 15 - "ScanResult"
Cohesion: 0.09
Nodes (25): Int, ScanResult, ScanState, cancelled, failed, finished, idle, running (+17 more)

### Community 16 - "ThinEnvironment"
Cohesion: 0.18
Nodes (15): ClusterType, Decoder, ClusterType, custom, rancher, rke2, GuardicoreAggregator, GuardicoreCluster (+7 more)

### Community 17 - "KubeContext"
Cohesion: 0.11
Nodes (23): CodingKey, CodingKeys, certificateAuthorityData, clusters, contexts, currentContext, insecureSkipTlsVerify, server (+15 more)

### Community 18 - "KubeJSONParser"
Cohesion: 0.18
Nodes (11): KubeAddress, KubeCalicoRule, KubeJSONParser, KubeMeta, KubePodSpec, CalicoPolicy, ClusterNode, ClusterPod (+3 more)

### Community 19 - "ThinEnvStore"
Cohesion: 0.18
Nodes (8): ThinEnvStore, GuardicoreAggregator, GuardicoreCluster, IndexSet, Int, ThinEnvironment, URL, UUID

### Community 20 - "ProxyJumpChain"
Cohesion: 0.19
Nodes (14): Hashable, Bool, Int, String, TunnelDescriptor, UUID, Kind, dynamic (+6 more)

### Community 21 - "ClusterTopologyView"
Cohesion: 0.20
Nodes (20): CGFloat, ClusterNode, ClusterPod, ClusterSnapshot, Color, GuardicoreAgent, Int, String (+12 more)

### Community 22 - "SSHSessionDescriptor / KubeContext"
Cohesion: 0.17
Nodes (17): Codable, NamespacePin, Sendable, UUID, Int, BaudRate, b115200, b19200 (+9 more)

### Community 25 - "TranscriptWriter"
Cohesion: 0.18
Nodes (9): DispatchQueue, FileHandle, ArraySlice, Int, String, UInt8, URL, UUID (+1 more)

### Community 26 - "Session"
Cohesion: 0.21
Nodes (12): AuthMethod, Session, SessionKind, AnySessionSpec, Bool, Int, ProxyJumpHop, SessionSpec (+4 more)

### Community 27 - "ClusterSnapshot"
Cohesion: 0.12
Nodes (15): ClusterHealthStatus, agentProblem, cniProblem, degraded, healthy, policySyncPending, ClusterSnapshot, PolicySnapshot (+7 more)

### Community 28 - "ClusterViewComponents / ClusterRawView"
Cohesion: 0.15
Nodes (14): RevisionAlignment, ClusterSnapshot, String, ClusterHealthStatus, Color, TerminalSession, RevisionChainCard, ClusterRawView (+6 more)

### Community 29 - "SSHConfigParserTests"
Cohesion: 0.12
Nodes (3): SSHConfigParserTests, URL, XCTestCase

### Community 30 - "ProxyJumpComposerView"
Cohesion: 0.20
Nodes (13): HopTestResult, Bool, Int, ProxyJumpHop, String, Void, ChainNodeView, HopRowView (+5 more)

### Community 31 - "SSHSessionDescriptor"
Cohesion: 0.14
Nodes (14): URL, SessionKind, local, serial, sftp, ssh, telnet, tunnelOnly (+6 more)

### Community 32 - "KubeJSONParser"
Cohesion: 0.17
Nodes (12): KubeCalicoSpec, KubeMeta, KubeNodeSpec, KubeNodeStatus, KubePodSpec, KubePodStatus, KubeStatefulSetSpec, KubeStatefulSetStatus (+4 more)

### Community 33 - "SSHSessionDescriptor"
Cohesion: 0.21
Nodes (8): ProxyJumpChain, Bool, AuthMethod, agent, key, keyboardInteractive, password, SSHSessionDescriptor

### Community 34 - "ConnectionDetailsSheet"
Cohesion: 0.21
Nodes (8): String, ThinEnvStore, ConnectionDetailsSheet, ConnectionTarget, aggregator, cluster, mgmt, thinEnv

### Community 35 - "MultiExecView"
Cohesion: 0.20
Nodes (6): MultiExecView, ActiveTerminalsStore, Bool, Set, String, UUID

### Community 36 - "GuardicoreStatusView"
Cohesion: 0.24
Nodes (6): ClusterSnapshot, GuardicoreAgent, Int, String, TerminalSession, GuardicoreStatusView

### Community 37 - "TunnelManagerView"
Cohesion: 0.31
Nodes (7): Binding, String, TunnelDescriptor, UUID, Void, TunnelEditorView, TunnelManagerView

### Community 38 - "KubeJSONParser"
Cohesion: 0.22
Nodes (8): RevisionChainStep, Status, error, ok, unknown, warning, ClusterSnapshot, RevisionAlignment

### Community 39 - "TerminalTabsView"
Cohesion: 0.31
Nodes (7): ActiveTerminalsStore, Bool, Color, KubeStore, TerminalSession, TabItemView, TerminalTabsView

### Community 40 - "AddAggregatorSheet"
Cohesion: 0.31
Nodes (6): Bool, GuardicoreAggregator, String, ThinEnvStore, UUID, AddAggregatorSheet

### Community 41 - "AddClusterSheet"
Cohesion: 0.31
Nodes (6): Bool, GuardicoreCluster, String, ThinEnvStore, UUID, AddClusterSheet

### Community 42 - "ClusterControlPanelView"
Cohesion: 0.32
Nodes (5): ClusterPanelTab, ClusterViewModel, String, TerminalSession, ClusterControlPanelView

### Community 43 - "KubeContextDockView"
Cohesion: 0.29
Nodes (5): KubeContextDockView, Snippet, ActiveTerminalsStore, KubeStore, String

### Community 44 - "SessionRowView"
Cohesion: 0.25
Nodes (7): SessionKind, SessionRowView, ActiveTerminalsStore, Color, Session, SessionStore, String

### Community 45 - "AddThinEnvSheet"
Cohesion: 0.29
Nodes (6): Bool, Int, String, ThinEnvironment, ThinEnvStore, AddThinEnvSheet

### Community 46 - "ClusterCommandsView"
Cohesion: 0.36
Nodes (5): String, TerminalSession, Void, ClusterCommandGroupView, ClusterCommandsView

### Community 47 - "ClusterSnapshotExport"
Cohesion: 0.47
Nodes (3): ClusterSnapshotExport, ClusterSnapshot, String

### Community 48 - "SSHDoubleHop"
Cohesion: 0.47
Nodes (3): SSHDoubleHop, String, ThinEnvironment

### Community 49 - "RootContentView"
Cohesion: 0.33
Nodes (5): RootContentView, ActiveTerminalsStore, KubeStore, SessionStore, ThinEnvStore

### Community 50 - "TerminalPaneView"
Cohesion: 0.33
Nodes (4): ColorScheme, Int32, TerminalSession, TerminalPaneView

### Community 52 - "ClusterPoliciesView"
Cohesion: 0.33
Nodes (4): CalicoPolicy, ClusterSnapshot, TerminalSession, ClusterPoliciesView

### Community 53 - "SSHToolLocator"
Cohesion: 0.50
Nodes (3): SSHToolLocator, Bool, String

### Community 54 - "HelmsmanApp"
Cohesion: 0.50
Nodes (3): App, HelmsmanApp, Scene

### Community 55 - "KubeJSONParser"
Cohesion: 0.50
Nodes (4): KubeAddress, KubeCondition, KubeNodeInfo, KubeNodeStatus

### Community 56 - "SettingsView"
Cohesion: 0.50
Nodes (3): SettingsView, KubeStore, SessionStore

### Community 60 - "KubeJSONParser"
Cohesion: 0.67
Nodes (3): KubeDeploySpec, KubeDeployStatus, KubeDeploymentItem

## Knowledge Gaps
- **339 isolated node(s):** `PreToolUse`, `SessionStore`, `ActiveTerminalsStore`, `Notification`, `NSUserActivityRestoring` (+334 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetworkScanner` connect `LocalProcessViewRepresentable / NetworkS` to `ActiveTerminalsStore`, `SSHSessionDescriptor / KubeContext`?**
  _High betweenness centrality (0.142) - this node is a cross-community bridge._
- **Why does `RevisionChainStep` connect `KubeJSONParser` to `KubeJSONParser`, `ClusterSnapshot`, `KubeJSONParser`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **Why does `TerminalSession` connect `TerminalSession` to `ClusterSnapshot`, `ActiveTerminalsStore`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **What connects `PreToolUse`, `SessionStore`, `ActiveTerminalsStore` to the rest of the system?**
  _339 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `LocalProcessViewRepresentable / NetworkS` be split into smaller, more focused modules?**
  _Cohesion score 0.06818181818181818 - nodes in this community are weakly interconnected._
- **Should `ThinEnvRow / PolicyDigestionView` be split into smaller, more focused modules?**
  _Cohesion score 0.07137254901960784 - nodes in this community are weakly interconnected._
- **Should `SnippetLibrary / WorkspaceProfile` be split into smaller, more focused modules?**
  _Cohesion score 0.06423034330011074 - nodes in this community are weakly interconnected._