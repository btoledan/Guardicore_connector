#!/bin/bash
# Mock kubectl
kubectl() {
  if [ "$1" = "get" ]; then
    echo "pod/gc-agents-daemonset-hzqnw"
  elif [ "$1" = "exec" ]; then
    echo "executing on $4: $6 $7 $8"
  fi
}
export -f kubectl

for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo "=== $pod ==="; kubectl exec -n guardicore $pod -- sh -c "grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3"; done
