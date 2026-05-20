import Foundation

struct AgentRevEntry {
    var policyRevision: Int?
    var dcInventory: String?
    var lastLine: String?
}

func parseAgentRevisionLogs(_ output: String) -> [String: AgentRevEntry] {
    var result: [String: AgentRevEntry] = [:]
    var currentPod: String?
    for line in output.components(separatedBy: .newlines) {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("=== pod/") || t.hasPrefix("=== gc-") {
            if t.hasPrefix("=== ") {
                currentPod = t.replacingOccurrences(of: "=== ", with: "")
                    .replacingOccurrences(of: "pod/", with: "")
                    .replacingOccurrences(of: " ===", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            continue
        }
        guard let pod = currentPod, !t.isEmpty else { continue }
        var entry = result[pod] ?? AgentRevEntry()
        entry.lastLine = t
        if let range = t.range(of: "Policy revision", options: .caseInsensitive) {
            let tail = t[range.upperBound...]
            let num = tail.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
            entry.policyRevision = num
        }
        if t.lowercased().contains("dc-inventory") || t.lowercased().contains("inventory revision") {
            let num = t.split(whereSeparator: { !$0.isNumber && $0 != "." }).last.map(String.init)
            entry.dcInventory = num
        }
        result[pod] = entry
    }
    return result
}

let sample = """
=== pod/gc-agents-daemonset-hzqnw ===
Policy revision 42
=== gc-agents-daemonset-pvk49 ===
Policy revision: 43
"""

print(parseAgentRevisionLogs(sample))
