	#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infra/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

SSH_KEY="${HOME}/.ssh/devdp_yc"
SSH_PUBLIC_KEY="${SSH_KEY}.pub"

YC_KEY_FILE="${YC_SERVICE_ACCOUNT_KEY_FILE:-${HOME}/.config/yandex-cloud/devdp-key.json}"

GITHUB_REPOSITORY="alesyakurilchik/devdp"


log() {
    echo
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}


require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required command '$1' was not found."
        exit 1
    fi
}


run_playbook() {
    local playbook="$1"

    for attempt in 1 2 3; do
        log "Ansible: ${playbook} (attempt ${attempt}/3)"

        rm -rf "${HOME}/.ansible/cp"
        mkdir -p "${HOME}/.ansible/cp"

        if (
            cd "${ANSIBLE_DIR}"
            ansible-playbook "${playbook}"
        ); then
            return 0
        fi

        echo "Playbook failed. Waiting before retry..."
        sleep 10
    done

    echo "ERROR: ${playbook} failed after 3 attempts."
    exit 1
}


log "1. CHECK PREREQUISITES"

for command_name in \
    terraform \
    ansible \
    ansible-playbook \
    docker \
    yc \
    gh \
    curl
do
    require_command "${command_name}"
done

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not available for the current user."
    exit 1
fi

if [ ! -f "${YC_KEY_FILE}" ]; then
    echo "ERROR: Yandex Cloud service account key was not found:"
    echo "${YC_KEY_FILE}"
    exit 1
fi

if [ ! -f "${SSH_KEY}" ]; then
    log "Creating SSH key for cloud VMs"

    ssh-keygen \
        -t ed25519 \
        -f "${SSH_KEY}" \
        -N "" \
        -C "devdp"
fi

if [ ! -f "${SSH_PUBLIC_KEY}" ]; then
    ssh-keygen \
        -y \
        -f "${SSH_KEY}" \
        > "${SSH_PUBLIC_KEY}"
fi


log "2. CONFIGURE YANDEX CLOUD AUTH"

export YC_SERVICE_ACCOUNT_KEY_FILE="${YC_KEY_FILE}"

if [ -z "${YC_CLOUD_ID:-}" ]; then
    YC_CLOUD_ID="$(yc config get cloud-id 2>/dev/null || true)"
    export YC_CLOUD_ID
fi

if [ -z "${YC_FOLDER_ID:-}" ]; then
    YC_FOLDER_ID="$(yc config get folder-id 2>/dev/null || true)"
    export YC_FOLDER_ID
fi

if [ -z "${YC_CLOUD_ID}" ]; then
    echo "ERROR: YC_CLOUD_ID is empty."
    exit 1
fi

if [ -z "${YC_FOLDER_ID}" ]; then
    echo "ERROR: YC_FOLDER_ID is empty."
    exit 1
fi

echo "Yandex Cloud authentication: OK"


log "3. TERRAFORM INIT"

terraform \
    -chdir="${TF_DIR}" \
    init \
    -input=false


log "4. TERRAFORM APPLY"

terraform \
    -chdir="${TF_DIR}" \
    apply \
    -auto-approve \
    -input=false


log "5. READ INFRASTRUCTURE OUTPUTS"

APP_PUBLIC_IP="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_public_ip
)"

APP_PRIVATE_IP="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_private_ip
)"

MON_PUBLIC_IP="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw monitoring_public_ip
)"

MON_PRIVATE_IP="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw monitoring_private_ip
)"

echo "APP PUBLIC:       ${APP_PUBLIC_IP}"
echo "APP PRIVATE:      ${APP_PRIVATE_IP}"
echo "MONITORING PUBLIC:${MON_PUBLIC_IP}"
echo "MONITORING PRIVATE:${MON_PRIVATE_IP}"


log "6. UPDATE GITHUB ACTIONS SECRETS"

gh secret set APP_HOST \
    --repo "${GITHUB_REPOSITORY}" \
    --body "${APP_PUBLIC_IP}"

gh secret set APP_PRIVATE_HOST \
    --repo "${GITHUB_REPOSITORY}" \
    --body "${APP_PRIVATE_IP}"

gh secret set APP_USER \
    --repo "${GITHUB_REPOSITORY}" \
    --body "ubuntu"

gh secret set MON_HOST \
    --repo "${GITHUB_REPOSITORY}" \
    --body "${MON_PUBLIC_IP}"

gh secret set SSH_PRIVATE_KEY \
    --repo "${GITHUB_REPOSITORY}" \
    < "${SSH_KEY}"

echo "GitHub deployment secrets: updated"


log "7. GENERATE ANSIBLE INVENTORY"

bash "${PROJECT_ROOT}/scripts/generate_inventory.sh"


log "8. WAIT FOR CLOUD VMS"

READY=0

for attempt in $(seq 1 18); do
    echo "Connection check ${attempt}/18"

    rm -rf "${HOME}/.ansible/cp"
    mkdir -p "${HOME}/.ansible/cp"

    if (
        cd "${ANSIBLE_DIR}"
        ansible all -m ping
    ); then
        READY=1
        break
    fi

    sleep 10
done

if [ "${READY}" -ne 1 ]; then
    echo "ERROR: cloud VMs are not reachable through Ansible."
    exit 1
fi


log "9. CONFIGURE SERVERS AND DEPLOY APPLICATION"

run_playbook "playbooks/site.yml"


log "10. DEPLOY MONITORING"

run_playbook "playbooks/monitoring.yml"


log "11. VERIFY APPLICATION"

(
    cd "${ANSIBLE_DIR}"

    ansible app \
        -b \
        -m shell \
        -a '
            set -e
            curl -fsS http://127.0.0.1:8000/health
            echo
            curl -fsS http://127.0.0.1:3000/ >/dev/null
            echo "Frontend: OK"
        '
)


log "12. VERIFY MONITORING"

(
    cd "${ANSIBLE_DIR}"

    ansible monitoring \
        -b \
        -m shell \
        -a '
            set -e
            curl -fsS http://127.0.0.1:9090/-/ready >/dev/null
            echo "Prometheus: OK"

            curl -fsS http://127.0.0.1:3000/api/health >/dev/null
            echo "Grafana: OK"

            curl -fsS http://127.0.0.1:9093/-/ready >/dev/null
            echo "Alertmanager: OK"
        '
)


log "BOOTSTRAP COMPLETED SUCCESSFULLY"

echo
echo "Application:"
echo "  Frontend:   http://${APP_PUBLIC_IP}:3000"
echo "  Backend:    http://${APP_PUBLIC_IP}:8000"
echo "  API docs:   http://${APP_PUBLIC_IP}:8000/docs"
echo
echo "Monitoring:"
echo "  Grafana:    http://${MON_PUBLIC_IP}:3000"
echo "  Prometheus: http://${MON_PUBLIC_IP}:9090"
echo "  Alertmanager: http://${MON_PUBLIC_IP}:9093"
echo
echo "Infrastructure, application and monitoring are ready."
