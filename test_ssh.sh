#!/bin/bash
sshpass() {
  echo "sshpass called with: $@"
}
ssh() {
  echo "ssh called with: $@"
}
export -f sshpass ssh

eval "sshpass -p 'pass' ssh user@host \"sshpass -p 'pass' ssh user@target 'for pod in \$(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== \$pod ===\"; kubectl exec -n guardicore \$pod -- sh -c \"grep -i '\''Policy revision'\'' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3\"; done'\""
