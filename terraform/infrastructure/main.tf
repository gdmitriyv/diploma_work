# ==============================================================================
# 1. СЕТЕВАЯ ИНФРАСТРУКТУРА (VPC), СТАТИЧЕСКИЙ IP И ГРУППЫ БЕЗОПАСНОСТИ
# ==============================================================================

# Создаем единую виртуальную сеть для диплома
resource "yandex_vpc_network" "diploma_network" {
  name        = "diploma-network"
  description = "Основная сеть для дипломного проекта DevOps"
}

# Подсеть в зоне A
resource "yandex_vpc_subnet" "subnet_a" {
  name           = "diploma-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma_network.id
  v4_cidr_blocks = ["10.10.1.0/24"]
}

# Подсеть в зоне B
resource "yandex_vpc_subnet" "subnet_b" {
  name           = "diploma-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma_network.id
  v4_cidr_blocks = ["10.10.2.0/24"]
}

# Подсеть в зоне D
resource "yandex_vpc_subnet" "subnet_d" {
  name           = "diploma-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.diploma_network.id
  v4_cidr_blocks = ["10.10.3.0/24"]
}

# Резервируем постоянный статический IP-адрес в облаке для мастер-ноды K8s
resource "yandex_vpc_address" "lb_static_ip" {
  name = "k8s-master-static-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# Группа безопасности (сетевой экран) для беспрепятственной работы Kubernetes
resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Сетевые правила для взаимодействия узлов self-hosted Kubernetes"
  network_id  = yandex_vpc_network.diploma_network.id

  # TODO (безопасность): по возможности ограничить источники SSH, API и NodePort
  # адресом управляющей машины вместо 0.0.0.0/0.
  ingress {
    protocol       = "TCP"
    description    = "Доступ по SSH для Ansible и администратора"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP для Grafana и тестового приложения через ingress-контроллер"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "Удаленное управление кластером через API Server"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    protocol       = "ANY"
    description    = "Полный внутренний трафик между мастером и воркерами (etcd, kubelet, CNI)"
    v4_cidr_blocks = ["10.10.1.0/24"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "Доступ к сервисам NodePort (для Grafana и тестового веб-сервера)"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  egress {
    protocol       = "ANY"
    description    = "Разрешить нодам весь исходящий трафик в интернет (для скачивания пакетов)"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# ==============================================================================
# 2. ПОДГОТОВКА ОБРАЗА ОС
# ==============================================================================

# Поиск актуального официального образа Ubuntu 24.04 LTS.
# ВАЖНО: семейство образов обновляется Яндексом, поэтому id образа со временем
# меняется. Чтобы это не приводило к пересозданию ВМ, в ресурсах ВМ ниже
# добавлен lifecycle.ignore_changes для image_id.
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

# ==============================================================================
# 3. ЭКОНОМИЧНЫЕ ВИРТУАЛЬНЫЕ МАШИНЫ ДЛЯ KUBESPRAY (3 НОДЫ ПО ТЗ)
# ==============================================================================

# Выделенная мастер-нода (Control Plane + etcd)
resource "yandex_compute_instance" "k8s_masters" {
  name        = "k8s-master-01"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 50 # Защита от таймаута kubeadm init
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20 # Расширенный объем диска против Disk Pressure
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    nat_ip_address     = yandex_vpc_address.lb_static_ip.external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id] # Применяем сетевой экран
  }

  scheduling_policy {
    preemptible = true # Прерываемая ВМ для экономии купона
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # ИСПРАВЛЕНО: новый образ в семействе не должен пересоздавать работающий кластер
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image_id]
  }
}

# Две рабочие воркер-ноды (минимальное требование ТЗ — 3 сервера суммарно)
resource "yandex_compute_instance" "k8s_workers" {
  count       = 2
  name        = "k8s-worker-0${count.index + 1}"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20 # Экономия 80% стоимости vCPU на рабочих узлах
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  # У воркеров внешние адреса динамические: после перезапуска прерываемой ВМ
  # они меняются, поэтому inventory.ini нужно перегенерировать (terraform apply).
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id] # Применяем сетевой экран
  }

  scheduling_policy {
    preemptible = true # Прерываемые ВМ
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # ИСПРАВЛЕНО: новый образ в семействе не должен пересоздавать работающий кластер
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image_id]
  }
}

# ==============================================================================
# 4. АВТОМАТИЧЕСКАЯ ГЕНЕРАЦИЯ ИНВЕНТАРЯ ДЛЯ KUBESPRAY
# ==============================================================================
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    masters_external = [yandex_compute_instance.k8s_masters.network_interface.0.nat_ip_address],
    masters_internal = [yandex_compute_instance.k8s_masters.network_interface.0.ip_address],
    workers_external = yandex_compute_instance.k8s_workers[*].network_interface.0.nat_ip_address,
    workers_internal = yandex_compute_instance.k8s_workers[*].network_interface.0.ip_address
  })
  filename = "${path.module}/../../kubespray-setup/kubespray/inventory/mycluster/inventory.ini"
}

# ==============================================================================
# 5. РЕЕСТР КОНТЕЙНЕРОВ (YANDEX CONTAINER REGISTRY)
# ==============================================================================

# Создание реестра для Docker-образов
resource "yandex_container_registry" "diploma_registry" {
  name      = "diploma-registry"
  folder_id = var.folder_id

  lifecycle {
    prevent_destroy = false
  }
}

# Публичное право на анонимное скачивание образов из реестра.
# Ноды кластера скачивают образ приложения без imagePullSecret.
# Не размещайте в этом реестре образы с секретами.
resource "yandex_container_registry_iam_binding" "public_puller" {
  registry_id = yandex_container_registry.diploma_registry.id
  role        = "container-registry.images.puller"
  members     = ["system:allUsers"]
}

# Вывод ID реестра в консоль после создания
output "container_registry_id" {
  value       = yandex_container_registry.diploma_registry.id
  description = "Идентификатор вашего сохраненного реестра"
}
