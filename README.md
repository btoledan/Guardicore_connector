# Guardicore_connector — Guardicore Operations Console

A macOS application for managing, monitoring, and debugging Guardicore-protected Kubernetes environments over double-hop SSH.

---

## What it does

Guardicore_connector connects your Mac directly to Guardicore thin environments and their Kubernetes clusters through a bastion host. From a single window you can:

- Open interactive SSH terminals to tester, management, aggregator, and cluster nodes
- View live cluster topology — nodes, pods, namespaces, GC agent coverage
- Monitor Guardicore system status: DaemonSet readiness, gc-kube-enforce, policy revision chain (CM → Agent → Calico CRD)
- Validate traffic allow/block behaviour and correlate results with agent verdict logs
- Inspect raw Calico NetworkPolicy CRDs and check for `action: Deny` enforcement
- Export cluster snapshots as Markdown or JSON for reports and handoffs
- Run Quick Actions (per-cluster typed commands) directly into the cluster terminal with automatic dashboard refresh

---

## Requirements

- macOS 13 or later
- Xcode 15 or later
- `sshpass` installed locally (`brew install hudochenkov/sshpass/sshpass`)
- `xcodegen` installed locally (`brew install xcodegen`)

---

## Getting started (fresh clone)

**Prerequisites: macOS 13+, Xcode 15+ (from the App Store)**

```bash
# 1. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install build tools
brew install hudochenkov/sshpass/sshpass xcodegen

# 3. Clone the repo
git clone https://github.com/btoledan/Guardicore_connector.git
cd Guardicore_connector

# 4. Build
make build

# 5. Run
open .build/DerivedData/Build/Products/Debug/Guardicore_connector.app
```

Steps 1–2 are one-time setup. After that, `make build && open ...` is all you need for every subsequent build.

---

## Project structure

```
Sources/
  Guardicore_connector/
    App/           — App entry point and menu commands
    Models/        — Data models, SSH double-hop, cluster view model, Kube parsers
    Views/
      ThinEnv/     — Environment sidebar, cluster panel, topology, overview, GC status
      Terminal/    — Terminal tabs and pane
      Sessions/    — Generic SSH session management
      SSH/         — Proxy jump composer, connection export
      Root/        — Sidebar and root content view
      Settings/    — App settings
  SSHKit/          — SSH config parsing and proxy-jump chain builder
  VaultKit/        — Keychain credential storage
  KubeKit/         — kubeconfig parsing and kubectl snippet library
  NetScanKit/      — Local network scanner
  TerminalKit/     — SwiftTerm-based terminal session wrapper
Tests/
  SSHKitTests/
  KubeKitTests/
scripts/           — DMG packaging and notarization scripts
project.yml        — XcodeGen project spec
```

---

## Architecture

### SSH double-hop

All remote connections go through two SSH hops:

```
Mac → bastion (thin env tester) → target host (cluster master / management / aggregator)
```

Authentication uses `sshpass` for password-based lab environments.

### Cluster View

The Cluster View panel runs background commands against the cluster master over the double-hop SSH connection and parses the output into a live snapshot.

The CLI tool and command set adapt automatically to the cluster type:

| Cluster type | Default IP | CLI | CNI |
|---|---|---|---|
| Rancher | 172.17.100.1 | `kubectl` | Calico |
| RKE2 | 172.17.50.1 | `kubectl` | Calico |
| k3s | 172.17.49.1 | `kubectl` | Calico |
| OpenShift | 172.17.0.55 | `oc` | OVN-Kubernetes |
| Custom | (user-defined) | `kubectl` | — |

- **Phase 1** — nodes and all pods (fast, populates topology immediately)
- **Phase 2** — Guardicore pods, DaemonSet, deployments, policies, agent revision logs, events. OpenShift also fetches `guardicore-orch`; Calico-specific commands are skipped on OVN clusters.

### Quick Actions

The Overview tab shows per-cluster Quick Actions that type commands directly into the live terminal. Actions are cluster-type aware (`kubectl` vs `oc`). After a Quick Action runs, the dashboard auto-refreshes (~1.5 s debounce) so metrics reflect the change immediately. Built-in actions can be hidden and custom actions added/removed from the Overview tab.

### Policy revision chain

The revision chain tracks whether Guardicore CM policies have propagated end-to-end:

```
CM publish → gc-agent policy revision → Calico CRD annotation
```

All three values are displayed together in the Overview tab so you can immediately see if a cluster is out of sync. On OpenShift clusters (OVN-Kubernetes CNI), Calico revision data is not applicable and is omitted from the chain.

---

## License

Internal tooling. Not for public distribution.
