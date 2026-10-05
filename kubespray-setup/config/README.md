# Конфигурация Kubespray

Кластер установлен через Kubespray `v2.25.1-6-g781f02fdd` (коммит `781f02fdd`).
Сам клон Kubespray (около 512 МБ) в репозиторий не входит, здесь только своя конфигурация.

## Что здесь лежит

| Файл | Назначение |
|---|---|
| `cluster.yml` | Заменяет оригинальный `cluster.yml`: запускает штатный плейбук `playbooks/cluster.yml`, затем выгружает kubeconfig с мастера на управляющую машину и подставляет внешний IP мастера |
| `inventory/mycluster/group_vars/all/all.yml` | Отличается от образца `inventory/sample` |
| `inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml` | Отличается от образца `inventory/sample` |
| `inventory/mycluster/patches/` | Патчи kubeadm для kube-controller-manager и kube-scheduler |

Файл `inventory.ini` создаёт Terraform (`terraform/infrastructure/inventory.tftpl`) при локальном `terraform apply`. Папка `credentials` содержит секретный ключ и в репозиторий не попадает.

## Как воспроизвести установку

```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout 781f02fdd
python3 -m venv venv && . venv/bin/activate
pip install -r requirements.txt
cp -r inventory/sample inventory/mycluster
cp ../kubespray-setup/config/cluster.yml cluster.yml
cp -r ../kubespray-setup/config/inventory/mycluster/. inventory/mycluster/
# inventory/mycluster/inventory.ini создаёт Terraform
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v
```

Отличия от образца можно посмотреть так:

```bash
diff -u inventory/sample/group_vars/all/all.yml inventory/mycluster/group_vars/all/all.yml
diff -u inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```
