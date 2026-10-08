# Дипломный практикум DevOps (Yandex Cloud)

Инфраструктура как код, Kubernetes-кластер, мониторинг и CI/CD для учебного дипломного проекта от DGV.
Всё развёртывается с нуля: проверено полным циклом `terraform destroy` и повторным созданием, скриншоты приложены ниже.

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
Логин пароль не переданы при сдаче на проверку.
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


## Адреса

На момент составления (значения меняются при каждом пересоздании стенда):

- Тестовое приложение: http://89.169.133.151/
- Grafana: http://89.169.133.151/grafana/ (логин `admin`, пароль у меня, не передавал)

Актуальный адрес мастера: `terraform -chdir=terraform/infrastructure output k8s_master_external_ip`. "Переменная, так как я отключил прерываемость только для сдачи VM в облаке"

terraform destroy и скрины инфраструктуры ДО удаления

<img width="1188" height="494" alt="06  terraform destroy" src="https://github.com/user-attachments/assets/38723b8b-c8c2-4db9-a935-f8ff99580035" />
<img width="1297" height="680" alt="05  kubectl get  pods До terraform destroy" src="https://github.com/user-attachments/assets/913d156b-e665-4dfd-b2fa-697509b8e57e" />
<img width="1247" height="897" alt="04  Приложение До terraform destroy" src="https://github.com/user-attachments/assets/35a8bb8d-f86e-4c5c-a940-615b6256f62f" />
<img width="1836" height="911" alt="04  grafana До terraform destroy" src="https://github.com/user-attachments/assets/d66efecd-845f-41ea-983e-998cc4a2adb2" />
<img width="1425" height="784" alt="03  Container Registry До terraform destroy" src="https://github.com/user-attachments/assets/06c1c5e2-a7dc-44c7-8cbe-774aea0dcf2c" />
<img width="1220" height="411" alt="02  Container Registry До terraform destroy" src="https://github.com/user-attachments/assets/4ac242d3-c71d-4837-87a0-7f1e411987a4" />
<img width="1718" height="427" alt="01  До terraform destroy" src="https://github.com/user-attachments/assets/f911715b-56a6-475f-84b9-34704ad4d2b8" />
<img width="1048" height="757" alt="07  terraform destroy" src="https://github.com/user-attachments/assets/b6202e20-9069-48c8-aa69-661e46a09391" />

terraform apply, скриншоты ПОСЛЕ redeploy

<img width="1754" height="803" alt="15 action git diploma work" src="https://github.com/user-attachments/assets/ed79844f-f59e-4ac9-b095-f41fea1fb536" />
<img width="1813" height="951" alt="14 action git diploma app" src="https://github.com/user-attachments/assets/72215288-187b-49e4-ba4f-d98c5e093b0b" />
<img width="1694" height="430" alt="13 up server" src="https://github.com/user-attachments/assets/e11fb07f-ac11-4d80-a724-46426eef4a7f" />
<img width="1240" height="784" alt="12  services UP" src="https://github.com/user-attachments/assets/bedada83-35ba-493a-a214-debdfd65d77a" />
<img width="1080" height="484" alt="12  Container Registry UP" src="https://github.com/user-attachments/assets/4c9b94f0-c569-4b87-95a5-937f5baa0dab" />
<img width="1837" height="984" alt="11  grafana up" src="https://github.com/user-attachments/assets/a0ad7f15-2655-436b-9f3a-b1c51f2f8e07" />
<img width="1426" height="839" alt="11  app up" src="https://github.com/user-attachments/assets/1b5b7a4a-a59c-4144-92a3-12093ae860a4" />
<img width="1243" height="568" alt="10  ansible playbook" src="https://github.com/user-attachments/assets/9f95eb86-13d7-44e1-a461-8497c9891bb2" />
<img width="1067" height="605" alt="09  run workflow" src="https://github.com/user-attachments/assets/00068b00-7a5c-4e18-af5d-49210e998230" />
<img width="1051" height="378" alt="08  terraform apply" src="https://github.com/user-attachments/assets/ecb78c0a-90bc-4dda-9ac9-07cd11ef28a9" />




