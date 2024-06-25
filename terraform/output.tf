output "cp_nodes" {
  value = [
    for n in yandex_compute_instance.kub-cp-nodes :
    "name=${n.name}, public=${n.network_interface.0.nat_ip_address}, private=${n.network_interface.0.ip_address}"
  ]
}

output "worker_nodes" {
  value = [
    for n in yandex_compute_instance.kub-worker-nodes :
    "name=${n.name}, public=${n.network_interface.0.nat_ip_address}, private=${n.network_interface.0.ip_address}"
  ]
}

output "gitlab" {
  value = [
    for n in yandex_compute_instance.gitlab :
    "name=${n.name}, public=${n.network_interface.0.nat_ip_address}, private=${n.network_interface.0.ip_address}"
  ]
}
