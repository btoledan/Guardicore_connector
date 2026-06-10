// ClusterCommands.swift — Shared kubectl/oc command groups for cluster terminal

import Foundation

struct ClusterCommandGroup {
    let title: String
    let icon: String
    let commands: [String]
}

enum ClusterCommands {

    // MARK: - Standard kubectl (Rancher / RKE2 / k3s)

    static let kubectlCommandGroups: [ClusterCommandGroup] = [
        ClusterCommandGroup(
            title: "Quick Status",
            icon: "bolt.fill",
            commands: [
                "kubectl get nodes -o wide",
                "kubectl get pods -n guardicore -o wide",
                "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
            ]
        ),
        ClusterCommandGroup(
            title: "Cluster Triage",
            icon: "magnifyingglass",
            commands: [
                "kubectl version --short 2>/dev/null || kubectl version",
                "kubectl get nodes -o wide",
                "kubectl get nodes --show-labels",
                "kubectl get pods -n kube-system -o wide",
                "kubectl get ns",
                "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
            ]
        ),
        ClusterCommandGroup(
            title: "Guardicore System",
            icon: "shield.lefthalf.filled",
            commands: [
                "kubectl get pods -n guardicore -o wide",
                "kubectl get ds -n guardicore",
                "kubectl get deploy -n guardicore",
                "kubectl get sts -n guardicore",
                "kubectl get pods -n guardicore -o wide | grep gc-kube-inventory",
                "kubectl describe ds gc-agents-daemonset -n guardicore",
                "kubectl get events -n guardicore --sort-by='.lastTimestamp' | tail -30",
                "kubectl logs -n guardicore deploy/gc-kube-enforce --tail=80",
                "kubectl logs -n guardicore gc-kube-inventory-0 --tail=80",
            ]
        ),
        ClusterCommandGroup(
            title: "Policy / CNI",
            icon: "network",
            commands: [
                "kubectl get networkpolicies.networking.k8s.io -A",
                "kubectl get networkpolicies.crd.projectcalico.org -A",
            ]
        ),
        ClusterCommandGroup(
            title: "Agent Debug",
            icon: "ant.fill",
            commands: [
                "for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; kubectl exec -n guardicore $pod -- sh -c \"grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3\"; done",
                "for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; kubectl exec -n guardicore $pod -- sh -c \"grep -i 'enforcement policy' /var/log/gc-enforcement-agent.log 2>/dev/null | tail -2\"; done",
            ]
        ),
        ClusterCommandGroup(
            title: "Quick Health",
            icon: "heart.fill",
            commands: [
                "kubectl get nodes -o wide",
                "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
                "kubectl get componentstatuses 2>/dev/null || kubectl get --raw /readyz?verbose",
            ]
        ),
    ]

    // MARK: - k3s specific

    static let k3sCommandGroups: [ClusterCommandGroup] = [
        ClusterCommandGroup(
            title: "Quick Status",
            icon: "bolt.fill",
            commands: [
                "kubectl get nodes -o wide",
                "kubectl get pods -n guardicore -o wide",
                "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
            ]
        ),
        ClusterCommandGroup(
            title: "k3s Cluster",
            icon: "bolt.horizontal.fill",
            commands: [
                "k3s --version",
                "kubectl get nodes -o wide",
                "kubectl get nodes --show-labels",
                "kubectl get ns",
                "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
                "systemctl status k3s 2>/dev/null || service k3s status 2>/dev/null",
            ]
        ),
        ClusterCommandGroup(
            title: "Guardicore System",
            icon: "shield.lefthalf.filled",
            commands: [
                "kubectl get pods -n guardicore -o wide",
                "kubectl get ds -n guardicore",
                "kubectl get deploy -n guardicore",
                "kubectl get sts -n guardicore",
                "kubectl describe ds gc-agents-daemonset -n guardicore",
                "kubectl get events -n guardicore --sort-by='.lastTimestamp' | tail -30",
                "kubectl logs -n guardicore deploy/gc-kube-enforce --tail=80",
            ]
        ),
        ClusterCommandGroup(
            title: "Policy / CNI",
            icon: "network",
            commands: [
                "kubectl get networkpolicies.networking.k8s.io -A",
                "kubectl get networkpolicies.crd.projectcalico.org -A",
            ]
        ),
        ClusterCommandGroup(
            title: "Agent Debug",
            icon: "ant.fill",
            commands: [
                "for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; kubectl exec -n guardicore $pod -- sh -c \"grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3\"; done",
            ]
        ),
    ]

    // MARK: - OpenShift (oc)
    // No Calico — uses OVN-Kubernetes CNI.
    // Has guardicore + guardicore-orch namespaces.

    static let openshiftCommandGroups: [ClusterCommandGroup] = [
        ClusterCommandGroup(
            title: "Quick Status",
            icon: "bolt.fill",
            commands: [
                "oc get nodes -o wide",
                "oc get pods -n guardicore -o wide",
                "oc get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed|.*Completed)'",
            ]
        ),
        ClusterCommandGroup(
            title: "Cluster Triage",
            icon: "magnifyingglass",
            commands: [
                "oc version",
                "oc get nodes -o wide",
                "oc get nodes --show-labels",
                "oc get ns",
                "oc get clusteroperators",
                "oc get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
            ]
        ),
        ClusterCommandGroup(
            title: "Guardicore System",
            icon: "shield.lefthalf.filled",
            commands: [
                "oc get pods -n guardicore -o wide",
                "oc get pods -n guardicore-orch -o wide",
                "oc get ds -n guardicore",
                "oc get deploy -n guardicore",
                "oc get deploy -n guardicore-orch",
                "oc describe ds gc-agents-daemonset -n guardicore",
                "oc get events -n guardicore --sort-by='.lastTimestamp' | tail -30",
                "oc logs -n guardicore deploy/gc-kube-enforce --tail=80",
            ]
        ),
        ClusterCommandGroup(
            title: "Policy / OVN",
            icon: "network",
            commands: [
                "oc get networkpolicies.networking.k8s.io -A",
                "oc get egressnetworkpolicy -A 2>/dev/null || true",
                "oc get network.operator cluster -o yaml 2>/dev/null | grep -A5 defaultNetwork",
            ]
        ),
        ClusterCommandGroup(
            title: "Agent Debug",
            icon: "ant.fill",
            commands: [
                "for pod in $(oc get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; oc exec -n guardicore $pod -- sh -c \"grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3\"; done",
                "for pod in $(oc get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; oc exec -n guardicore $pod -- sh -c \"grep -i 'enforcement policy' /var/log/gc-enforcement-agent.log 2>/dev/null | tail -2\"; done",
            ]
        ),
        ClusterCommandGroup(
            title: "Quick Health",
            icon: "heart.fill",
            commands: [
                "oc get nodes -o wide",
                "oc get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
                "oc get clusteroperators | grep -v True.*False.*False",
            ]
        ),
    ]

    // MARK: - Selector

    /// Returns the right command groups for a given cluster type raw value.
    static func groups(forClusterType type: String?) -> [ClusterCommandGroup] {
        switch type {
        case GuardicoreCluster.ClusterType.openshift.rawValue: return openshiftCommandGroups
        case GuardicoreCluster.ClusterType.k3s.rawValue:       return k3sCommandGroups
        default:                                                return kubectlCommandGroups
        }
    }

    // MARK: - Legacy alias (used when cluster type is unknown)

    static var allCommandGroups: [ClusterCommandGroup] { kubectlCommandGroups }

    // MARK: - Quick Action built-ins (per cluster type)

    static func quickActionBuiltIns(forClusterType type: String?) -> [String] {
        switch type {
        case GuardicoreCluster.ClusterType.openshift.rawValue:
            return [
                "oc get nodes -o wide",
                "oc get pods -n guardicore -o wide",
                "oc get pods -n guardicore-orch -o wide",
                "oc get networkpolicies.networking.k8s.io -A",
                "oc get events -n guardicore --sort-by=.lastTimestamp",
            ]
        case GuardicoreCluster.ClusterType.k3s.rawValue:
            return [
                "kubectl get nodes -o wide",
                "kubectl get pods -n guardicore -o wide",
                "kubectl get networkpolicies.crd.projectcalico.org -A",
                "kubectl get events -n guardicore --sort-by=.lastTimestamp",
            ]
        default:
            return [
                "kubectl get nodes -o wide",
                "kubectl get pods -n guardicore -o wide",
                "kubectl get networkpolicies.crd.projectcalico.org -A",
                "kubectl get events -n guardicore --sort-by=.lastTimestamp",
            ]
        }
    }

    /// Legacy static list — kept for callers that don't yet pass cluster type.
    static let quickActionBuiltIns: [String] = quickActionBuiltIns(forClusterType: nil)
}
