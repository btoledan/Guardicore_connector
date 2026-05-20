#!/bin/bash
# Mock sshpass and ssh to just echo their arguments
sshpass() {
  echo "sshpass called with: $@"
}
ssh() {
  echo "ssh called with: $@"
}
export -f sshpass ssh

# The exact string Swift generated
eval "sshpass -p 'pass' ssh user@host \"sshpass -p 'pass' ssh user@target 'grep -i '\''Policy revision'\'''\""
