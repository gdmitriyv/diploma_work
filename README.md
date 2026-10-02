# Дипломный практикум DevOps (Yandex Cloud)

Инфраструктура как код и конфигурация кластера Kubernetes для дипломного проекта.

## Структура репозитория

| Папка | Содержимое |
|---|---|
| `terraform/bootstrap` | Сервисный аккаунт, KMS-ключ и S3-бакет для хранения state |
| `terraform/infrastructure` | VPC, подсети, группа безопасности, три ВМ, реестр контейнеров |
| `k8s-manifests/monitoring` | Настройки kube-prometheus-stack (Prometheus, Alertmanager, Grafana) |
| `k8s-manifests/traefik` | Настройки Ingress-контроллера Traefik |
| `k8s-manifests/app` | Манифесты тестового приложения |

Конфигурация Kubespray и репозиторий тестового приложения (`diploma-app`) добавляются отдельно.

## Адреса

- Тестовое приложение: http://62.84.115.226/
- Grafana: http://62.84.115.226/grafana/ (учётные данные передаются отдельно)

## Развёртывание с нуля (кратко)

1. `terraform/bootstrap`: `terraform init && terraform apply` создаёт сервисный аккаунт и бакет.
2. `terraform/infrastructure`: `terraform init && terraform apply` создаёт сеть, ВМ и реестр.
3. Kubernetes ставится через Kubespray (версия и конфигурация описаны отдельно).
4. Ingress-контроллер, мониторинг и приложение:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install traefik traefik/traefik --version 41.6.0 -n traefik --create-namespace \
  -f k8s-manifests/traefik/values.yaml
helm upgrade --install k8s-monitoring prometheus-community/kube-prometheus-stack \
  --version 91.8.2 -n monitoring --create-namespace -f k8s-manifests/monitoring/values.yaml
kubectl apply -f k8s-manifests/app/nginx-app.yaml
```
