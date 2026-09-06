# DevDP — DevOps Final Project

DevOps-проект с полностью автоматизированным созданием инфраструктуры,
конфигурацией серверов, CI/CD, мониторингом и Telegram-уведомлениями.

## Архитектура

Проект использует две виртуальные машины в Yandex Cloud:

- `devdp-app` — приложение;
- `devdp-monitoring` — мониторинг и bastion host.

Общая схема:

GitHub → GitHub Actions → devdp-monitoring → private network → devdp-app

На `devdp-app` работают:

- PostgreSQL;
- FastAPI backend;
- React frontend;
- Nginx;
- Node Exporter.

На `devdp-monitoring` работают:

- Prometheus;
- Grafana;
- Alertmanager;
- Blackbox Exporter;
- Node Exporter.

## Технологии

- Ubuntu Server 24.04
- Yandex Cloud
- Terraform
- Ansible
- Docker
- Docker Compose
- Git
- GitHub
- GitHub Actions
- GitHub Container Registry
- PostgreSQL
- FastAPI
- React
- Nginx
- Prometheus
- Grafana
- Alertmanager
- Blackbox Exporter
- Node Exporter
- Telegram Bot API

## Структура проекта

    devdp/
    ├── .github/
    │   └── workflows/
    │       └── ci-cd.yml
    ├── ansible/
    │   ├── inventory/
    │   ├── playbooks/
    │   │   ├── site.yml
    │   │   └── monitoring.yml
    │   └── roles/
    │       ├── common/
    │       ├── docker/
    │       ├── app/
    │       ├── monitoring/
    │       └── node_exporter/
    ├── backend/
    ├── frontend/
    ├── infra/
    │   └── terraform/
    ├── scripts/
    │   ├── bootstrap.sh
    │   └── generate_inventory.sh
    ├── docs/
    │   └── RUNBOOK.md
    ├── docker-compose.yml
    ├── docker-compose.deploy.yml
    ├── Makefile
    └── README.md

## Infrastructure as Code

Terraform создаёт инфраструктуру в Yandex Cloud:

- Virtual Private Cloud;
- subnet;
- Security Groups;
- VM `devdp-app`;
- VM `devdp-monitoring`;
- публичные и приватные IP-адреса.

Проверка Terraform:

    terraform -chdir=infra/terraform validate

Просмотр ресурсов:

    terraform -chdir=infra/terraform plan

## Configuration Management

Ansible автоматически настраивает обе виртуальные машины.

Основной playbook:

    ansible/playbooks/site.yml

Monitoring playbook:

    ansible/playbooks/monitoring.yml

Проверка доступности:

    cd ansible
    ansible all -m ping

Повторный запуск playbook не изменяет уже настроенные базовые ресурсы,
что подтверждает идемпотентность конфигурации.

## One-command deployment

Полное развёртывание выполняется одной командой:

    make bootstrap

Она автоматически выполняет:

1. проверку необходимых инструментов;
2. Terraform init;
3. Terraform apply;
4. получение IP виртуальных машин;
5. обновление GitHub Actions Secrets;
6. генерацию Ansible inventory;
7. ожидание доступности VM;
8. настройку серверов через Ansible;
9. deployment приложения;
10. deployment monitoring stack;
11. health checks.

Проверка конфигураций без deployment:

    make check

## Application

На `devdp-app` запускаются:

- PostgreSQL;
- FastAPI backend;
- React/Nginx frontend.

Проверка backend:

    curl http://APP_IP:8000/health

Ожидаемый ответ:

    {"status":"healthy","database":"connected"}

Frontend:

    http://APP_IP:3000

FastAPI documentation:

    http://APP_IP:8000/docs

## CI/CD

Pipeline находится в:

    .github/workflows/ci-cd.yml

Для push в любую ветку выполняются:

- backend lint;
- backend tests;
- frontend lint;
- TypeScript check;
- frontend tests;
- frontend build;
- Docker build;
- smoke tests;
- создание Docker artifact.

Для `main` дополнительно выполняются:

- публикация Docker images в GHCR;
- автоматический deployment в Yandex Cloud;
- post-deploy smoke tests;
- Telegram notification.

Deployment выполняется через `devdp-monitoring`, используемый как
bastion host. Доступ к `devdp-app` выполняется по private IP.

## GitHub Container Registry

После успешной сборки ветки `main` backend и frontend Docker images
публикуются в GitHub Container Registry.

Используются теги:

- SHA текущего commit;
- `latest`.

## Monitoring

Prometheus собирает системные метрики обеих VM через Node Exporter.

Blackbox Exporter проверяет:

- backend;
- frontend.

Grafana использует Prometheus как datasource.

Основной dashboard:

    DevDP Overview

Настроены alert rules:

- `ApplicationEndpointDown`;
- `NodeExporterDown`;
- `HighMemoryUsage`.

## Telegram notifications

После выполнения GitHub Actions pipeline Telegram-бот отправляет
результат CI/CD.

Уведомление содержит:

- SUCCESS / FAILED;
- repository;
- branch;
- commit;
- backend checks;
- frontend checks;
- Docker build;
- deployment result;
- ссылку на GitHub Actions run.

## GitHub Actions Secrets

Используются:

    APP_HOST
    APP_PRIVATE_HOST
    APP_USER
    MON_HOST
    SSH_PRIVATE_KEY
    TELEGRAM_BOT_TOKEN
    TELEGRAM_CHAT_ID

Значения секретов не хранятся в Git.

## Security

В репозиторий не добавляются:

- `.env`;
- SSH private keys;
- Yandex Cloud service account key;
- Terraform state;
- Telegram Bot Token;
- динамический Ansible inventory с IP.

## Удаление инфраструктуры

После завершения демонстрации:

    terraform -chdir=infra/terraform destroy

Перед удалением можно посмотреть план:

    terraform -chdir=infra/terraform plan -destroy
