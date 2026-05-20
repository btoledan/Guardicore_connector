import Foundation

let command = "grep -i 'Policy revision'"
let escaped = command
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "$", with: "\\$")
    .replacingOccurrences(of: "`", with: "\\`")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "'", with: "'\\''")

let shell = "sshpass -p 'pass' ssh user@host \"sshpass -p 'pass' ssh user@target '\(escaped)'\""
print(shell)
