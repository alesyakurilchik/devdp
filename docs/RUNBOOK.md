# DevDP Runbook

## Проверка состояния инфраструктуры

    cd ~/projects/devdp
    terraform -chdir=infra/terraform output
    yc compute instance list

## Проверка Ansible

    cd ~/projects/devdp/ansible
    ansible all -m ping

Обе VM должны вернуть:

    SUCCESS
    ping: pong

## Проверка application stack

    ansible app -b -a \
    "docker compose -f /opt/devdp/docker-compose.deploy.yml ps"

Backend, frontend и database должны иметь состояние `Up`.

## Проверка backend

    cd ~/projects/devdp
    APP_IP=$(terraform -chdir=infra/terraform output -raw app_public_ip)
    curl -fsS "http://${APP_IP}:8000/health"

Ожидается:

    {"status":"healthy","database":"connected"}

## Проверка frontend

    curl -sS -o /dev/null \
      -w "HTTP %{http_code}\n" \
      "http://${APP_IP}:3000/"

Ожидается:

    HTTP 200

## Проверка monitoring stack

    cd ~/projects/devdp/ansible

    ansible monitoring -b -a \
    "docker compose -f /opt/devdp-monitoring/docker-compose.yml ps"

Должны работать:

- Prometheus;
- Grafana;
- Alertmanager;
- Blackbox Exporter.

## Проверка Node Exporter

    ansible all -b -m shell -a \
    'curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9100/metrics'

Ожидается HTTP 200 для обеих VM.

## Проверка Prometheus targets

    cd ~/projects/devdp

    MON_IP=$(terraform -chdir=infra/terraform output -raw monitoring_public_ip)

    curl -s "http://${MON_IP}:9090/api/v1/targets" |
    jq -r '.data.activeTargets[] |
    [.labels.job, .labels.instance, .health] | @tsv'

Все targets должны иметь состояние:

    up

## Проверка alert rules

    curl -s "http://${MON_IP}:9090/api/v1/rules" |
    jq -r '.data.groups[].rules[] |
    [.name, .state] | @tsv'

Должны присутствовать:

    ApplicationEndpointDown
    NodeExporterDown
    HighMemoryUsage

## Проверка GitHub Actions

    gh run list \
      --repo alesyakurilchik/devdp \
      --limit 5

## Полное повторное развёртывание

    cd ~/projects/devdp
    make bootstrap

## Проверка конфигураций

    make check

## Backend logs

    cd ~/projects/devdp/ansible

    ansible app -b -m shell -a \
    "docker logs --tail 100 devdp-backend-1"

## Frontend logs

    ansible app -b -m shell -a \
    "docker logs --tail 100 devdp-frontend-1"

## Prometheus logs

    ansible monitoring -b -m shell -a \
    "docker logs --tail 100 devdp-monitoring-prometheus-1"

## Grafana logs

    ansible monitoring -b -m shell -a \
    "docker logs --tail 100 devdp-monitoring-grafana-1"

## Удаление инфраструктуры

Выполнять только после защиты проекта:

    terraform -chdir=infra/terraform destroy
