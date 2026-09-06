#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infra/terraform"
INVENTORY="${PROJECT_ROOT}/ansible/inventory/hosts.ini"

ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"
SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-${HOME}/.ssh/devdp_yc}"

APP_PUBLIC_IP="$(
    terraform -chdir="${TF_DIR}" output -raw app_public_ip
)"

APP_PRIVATE_IP="$(
    terraform -chdir="${TF_DIR}" output -raw app_private_ip
)"

MON_PUBLIC_IP="$(
    terraform -chdir="${TF_DIR}" output -raw monitoring_public_ip
)"

MON_PRIVATE_IP="$(
    terraform -chdir="${TF_DIR}" output -raw monitoring_private_ip
)"

printf '%s\n' \
    '[app]' \
    "devdp-app ansible_host=${APP_PUBLIC_IP} private_ip=${APP_PRIVATE_IP} ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}" \
    '' \
    '[monitoring]' \
    "devdp-monitoring ansible_host=${MON_PUBLIC_IP} private_ip=${MON_PRIVATE_IP} ansible_user=${ANSIBLE_USER} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}" \
    '' \
    '[all:vars]' \
    'ansible_python_interpreter=/usr/bin/python3' \
    > "${INVENTORY}"

echo "Inventory generated"
echo "Ansible user: ${ANSIBLE_USER}"
echo "SSH key: ${SSH_PRIVATE_KEY_FILE}"
echo "APP PUBLIC: ${APP_PUBLIC_IP}"
echo "APP PRIVATE: ${APP_PRIVATE_IP}"
echo "MON PUBLIC: ${MON_PUBLIC_IP}"
echo "MON PRIVATE: ${MON_PRIVATE_IP}"
