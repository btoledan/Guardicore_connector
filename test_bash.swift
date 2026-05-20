import Foundation

let cmd = """
for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo "=== $pod ==="; kubectl exec -n guardicore $pod -- sh -c "grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3"; done
"""

let escaped = cmd
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "$", with: "\\$")
    .replacingOccurrences(of: "`", with: "\\`")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "'", with: "'\\''")

let shell = "sshpass -p 'pass' ssh user@host \"sshpass -p 'pass' ssh user@target '\(escaped)'\""

let process = Process()
let pipe = Pipe()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = ["-lc", "echo \(shell)"]
process.standardOutput = pipe
try! process.run()
process.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
print(String(data: data, encoding: .utf8)!)
