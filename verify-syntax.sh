#!/usr/bin/env bash
# Verify playbooks and roles load without syntax or parsing errors.
# Run before committing or deploying: ./verify-syntax.sh
set -e
INVENTORY="${1:-inventory.ini}"

echo "=== Ansible syntax check (catches YAML/task parsing errors) ==="
ansible-playbook -i "$INVENTORY" site.yml --syntax-check
ansible-playbook -i "$INVENTORY" create-k8s-readonly-client-cert.yml --syntax-check

echo "=== Load all tasks (validates every role loads) ==="
ansible-playbook -i "$INVENTORY" site.yml --list-tasks > /dev/null
ansible-playbook -i "$INVENTORY" create-k8s-readonly-client-cert.yml --list-tasks > /dev/null

echo "OK: syntax and task load passed."
