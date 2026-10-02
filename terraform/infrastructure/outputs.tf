output "k8s_master_external_ip" {
  description = "Постоянный статический внешний IP-адрес Мастер-ноды"
  value       = yandex_vpc_address.lb_static_ip.external_ipv4_address[0].address
}

output "k8s_master_internal_ip" {
  description = "Внутренний приватный IP-адрес Мастер-ноды"
  value       = yandex_compute_instance.k8s_masters.network_interface.0.ip_address
}

output "k8s_workers_external_ips" {
  description = "Динамические внешние IP-адреса Воркер-нод"
  value       = yandex_compute_instance.k8s_workers[*].network_interface.0.nat_ip_address
}

output "k8s_workers_internal_ips" {
  description = "Внутренние приватные IP-адреса Воркер-нод"
  value       = yandex_compute_instance.k8s_workers[*].network_interface.0.ip_address
}
