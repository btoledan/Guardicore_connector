// AggregatorCommands.swift — Shared monicore-ctrl command groups for the aggregator terminal.
//
// monicore-ctrl <action> <service_name>/<group_name>/all/*
//   actions: status, start, stop, restart, reload, reconnect,
//            upgrade, remove, resume-upgrade, diff-patch
//   flags:   -v/--verbose  -e/--error  -f/--force

import Foundation

enum AggregatorCommands {

    /// Grouped monicore-ctrl shortcuts shown in the aggregator "Commands" tab.
    static let commandGroups: [ClusterCommandGroup] = [
        ClusterCommandGroup(
            title: "Status",
            icon: "bolt.fill",
            commands: [
                "monicore-ctrl status",
                "monicore-ctrl status all -v",
                "monicore-ctrl status all -e",
            ]
        ),
        ClusterCommandGroup(
            title: "Service Control",
            icon: "gearshape.2.fill",
            commands: [
                "monicore-ctrl restart all",
                "monicore-ctrl reload all",
                "monicore-ctrl restart all -f",
                "monicore-ctrl stop all",
                "monicore-ctrl start all",
            ]
        ),
        ClusterCommandGroup(
            title: "Core Services",
            icon: "shield.lefthalf.filled",
            commands: [
                "monicore-ctrl status gc-enforcement -e",
                "monicore-ctrl status gc-controller-server -e",
                "monicore-ctrl status gc-mitigation -e",
                "monicore-ctrl status gc-datapath -e",
                "monicore-ctrl status gc-detection-agents-server -e",
                "monicore-ctrl status gc-dc-inventory -e",
                "monicore-ctrl status gc-cluster-mgr -e",
            ]
        ),
        ClusterCommandGroup(
            title: "Databases & Infra",
            icon: "cylinder.split.1x2.fill",
            commands: [
                "monicore-ctrl status redis-config-db -e",
                "monicore-ctrl status redis-agents-db -e",
                "monicore-ctrl status redis-dc-inventory-db -e",
                "monicore-ctrl status aggr-zookeeper -e",
                "monicore-ctrl status aggr-ssl-proxy -e",
                "monicore-ctrl status nginx -e",
            ]
        ),
    ]

    /// Prominent one-tap actions surfaced at the top of the aggregator panel.
    static let quickActionBuiltIns: [String] = [
        "monicore-ctrl status",
        "monicore-ctrl status all -v",
        "monicore-ctrl status all -e",
        "monicore-ctrl restart all",
    ]

    /// Per-service actions offered in each service row's context menu.
    /// `command(for:)` builds the full monicore-ctrl line for a given service name.
    struct ServiceAction: Identifiable {
        let title: String
        let icon: String
        /// monicore-ctrl arguments with `%@` standing in for the service name.
        let template: String
        /// Disruptive actions (start/stop/restart/…) get a confirmation prompt.
        let disruptive: Bool
        var id: String { title }

        func command(for service: String) -> String {
            "monicore-ctrl " + String(format: template, service)
        }
    }

    static let serviceActions: [ServiceAction] = [
        ServiceAction(title: "Status (verbose)", icon: "doc.text.magnifyingglass", template: "status %@ -v", disruptive: false),
        ServiceAction(title: "Status (errors)",  icon: "exclamationmark.triangle", template: "status %@ -e", disruptive: false),
        ServiceAction(title: "Restart",          icon: "arrow.clockwise",          template: "restart %@",   disruptive: true),
        ServiceAction(title: "Reload",           icon: "arrow.triangle.2.circlepath", template: "reload %@", disruptive: true),
        ServiceAction(title: "Stop",             icon: "stop.fill",                template: "stop %@",      disruptive: true),
        ServiceAction(title: "Start",            icon: "play.fill",                template: "start %@",     disruptive: true),
        ServiceAction(title: "Reconnect",        icon: "cable.connector",          template: "reconnect %@", disruptive: true),
    ]
}
