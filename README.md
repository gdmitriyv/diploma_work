# Дипломный практикум DevOps (Yandex Cloud)

Инфраструктура как код, Kubernetes-кластер, мониторинг и CI/CD для учебного дипломного проекта.
Всё развёртывается с нуля по инструкции ниже: проверено полным циклом `terraform destroy` и повторным созданием.

| Этап | Что сделано |
|---|---|
| 1. Облачная инфраструктура | Terraform: сеть, подсети, группа безопасности, три ВМ, реестр образов. State в зашифрованном S3-бакете |
| 2. Kubernetes | Self-hosted кластер на Kubespray: 1 мастер и 2 воркера |
| 3. Тестовое приложение | nginx со статической страницей, образ в Yandex Container Registry (репозиторий [diploma-app](https://github.com/gdmitriyv/diploma-app)) |
| 4. Мониторинг и деплой | Prometheus, Alertmanager, Grafana (kube-prometheus-stack), Ingress на Traefik, Terraform pipeline в GitHub Actions |
| 5. CI/CD | Сборка образа при каждом коммите, деплой в кластер при создании тега `v*` |

## Архитектура

```
GitHub ── Actions ──► terraform apply ──► Yandex Cloud
   │                                        ├─ VPC, подсети, группа безопасности
   │                                        ├─ k8s-master-01 (статический IP)
   │                                        ├─ k8s-worker-01, k8s-worker-02
   │                                        └─ Container Registry
   │
diploma-app ── Actions ──► build ──► образ в Container Registry
                              └─ тег v* ──► kubectl set image ──► Deployment nginx-app

Пользователь ──► http://<IP мастера>/          ──► Traefik (hostPort 80) ──► nginx-app
              └► http://<IP мастера>/grafana/ ──► Traefik ──► Grafana ◄── Prometheus ◄── node-exporter, kube-state-metrics
```

## Структура репозитория

| Папка | Содержимое |
|---|---|
| `terraform/bootstrap` | Сервисный аккаунт, KMS-ключ и S3-бакет для state (выполняется один раз, state локальный) |
| `terraform/infrastructure` | VPC, подсети, группа безопасности, ВМ, реестр, сервисный аккаунт CI, инвентарь для Kubespray |
| `kubespray-setup/config` | Конфигурация Kubespray: плейбук `cluster.yml`, `group_vars`, патчи kubeadm |
| `k8s-manifests/traefik` | Значения Helm для Ingress-контроллера Traefik |
| `k8s-manifests/monitoring` | Значения Helm для kube-prometheus-stack |
| `k8s-manifests/app` | Манифесты тестового приложения и права для CI (`ci-rbac.yaml`) |
| `.github/workflows/terraform.yml` | Пайплайн Terraform |
| `docs/screenshots` | Скриншоты работы стенда |

## Адреса

На момент составления (значения меняются при каждом пересоздании стенда):

- Тестовое приложение: http://89.169.133.151/
- Grafana: http://89.169.133.151/grafana/ (логин `admin`, пароль у меня, не передавал)

Актуальный адрес мастера: `terraform -chdir=terraform/infrastructure output k8s_master_external_ip`. "Переменная, так как я отключил прерываемость только для сдачи VM в облаке"

