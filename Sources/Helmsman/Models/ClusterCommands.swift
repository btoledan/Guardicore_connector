// ClusterCommands.swift — Shared kubectl command groups for cluster terminal

import Foundation

struct ClusterCommandGroup {
    let title: String
    let icon: String
    let commands: [String]
}

enum ClusterCommands {
    static let allCommandGroups: [ClusterCommandGroup] = [
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

    static let quickActionBuiltIns: [String] = [
        "kubectl get nodes -o wide",
        "kubectl get pods -n guardicore -o wide",
        "kubectl get networkpolicies.crd.projectcalico.org -A",
        "kubectl get events -n guardicore --sort-by=.lastTimestamp",
    ]
}
