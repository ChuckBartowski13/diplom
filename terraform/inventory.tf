resource "local_file" "k8s-cluster" {
  count   = 1
  content = <<-DOC

	---
	kube_config_dir: /etc/kubernetes
	kube_script_dir: "{{ bin_dir }}/kubernetes-scripts"
	kube_manifest_dir: "{{ kube_config_dir }}/manifests"

	kube_cert_dir: "{{ kube_config_dir }}/ssl"

	kube_token_dir: "{{ kube_config_dir }}/tokens"

	kube_api_anonymous_auth: true

	kube_version: v1.29.5

	local_release_dir: "/tmp/releases"

	retry_stagger: 5

	kube_owner: kube

	kube_cert_group: kube-cert

	kube_log_level: 2

	credentials_dir: "{{ inventory_dir }}/credentials"



	kube_network_plugin: calico

	kube_network_plugin_multus: false

	kube_service_addresses: 10.233.0.0/18

	kube_pods_subnet: 10.233.64.0/18

	kube_network_node_prefix: 24

	enable_dual_stack_networks: false

	kube_service_addresses_ipv6: fd85:ee78:d8a6:8607::1000/116

	kube_pods_subnet_ipv6: fd85:ee78:d8a6:8607::1:0000/112

	kube_network_node_prefix_ipv6: 120

	kube_apiserver_ip: "{{ kube_service_addresses | ansible.utils.ipaddr('net') | ansible.utils.ipaddr(1) | ansible.utils.ipaddr('address') }}"
	kube_apiserver_port: 6443  # (https)

	kube_proxy_mode: ipvs

	kube_proxy_strict_arp: false

	kube_proxy_nodeport_addresses: >-
	  {%- if kube_proxy_nodeport_addresses_cidr is defined -%}
	  [{{ kube_proxy_nodeport_addresses_cidr }}]
	  {%- else -%}
	  []
	  {%- endif -%}


	kube_encrypt_secret_data: false

	cluster_name: cluster.local

	ndots: 2

	dns_mode: coredns

	enable_nodelocaldns: true
	enable_nodelocaldns_secondary: false
	nodelocaldns_ip: 169.254.25.10
	nodelocaldns_health_port: 9254
	nodelocaldns_second_health_port: 9256
	nodelocaldns_bind_metrics_host_ip: false
	nodelocaldns_secondary_skew_seconds: 5

	enable_coredns_k8s_external: false
	coredns_k8s_external_zone: k8s_external.local

	enable_coredns_k8s_endpoint_pod_names: false

	resolvconf_mode: host_resolvconf

	deploy_netchecker: false

	skydns_server: "{{ kube_service_addresses | ansible.utils.ipaddr('net') | ansible.utils.ipaddr(3) | ansible.utils.ipaddr('address') }}"
	skydns_server_secondary: "{{ kube_service_addresses | ansible.utils.ipaddr('net') | ansible.utils.ipaddr(4) | ansible.utils.ipaddr('address') }}"
	dns_domain: "{{ cluster_name }}"

	container_manager: containerd

	kata_containers_enabled: false

	kubeadm_certificate_key: "{{ lookup('password', credentials_dir + '/kubeadm_certificate_key.creds length=64 chars=hexdigits') | lower }}"

	k8s_image_pull_policy: IfNotPresent

	kubernetes_audit: false

	default_kubelet_config_dir: "{{ kube_config_dir }}/dynamic_kubelet_dir"

	volume_cross_zone_attachment: false

	event_ttl_duration: "1h0m0s"

	auto_renew_certificates: false

	kubeadm_patches:
	  enabled: false
	  source_dir: "{{ inventory_dir }}/patches"
	  dest_dir: "{{ kube_config_dir }}/patches"

	remove_anonymous_access: false
	supplementary_addresses_in_ssl_keys: [${yandex_compute_instance.kub-cp-nodes[count.index].network_interface.0.nat_ip_address}]

        DOC
  filename = "../kubespray/inventory/kub-cluster/group_vars/k8s_cluster/k8s-cluster.yml"

  depends_on = [
    yandex_compute_instance.kub-cp-nodes
  ]
}



data "template_file" "inventory" {
  template = file("./templates/inventory.tpl")
    
  vars = {
    connection_strings_cp = join("\n", formatlist("%s ansible_host=%s", yandex_compute_instance.kub-cp-nodes.*.name, yandex_compute_instance.kub-cp-nodes.*.network_interface.0.nat_ip_address))
    connection_strings_worker   = join("\n", formatlist("%s ansible_host=%s", yandex_compute_instance.kub-worker-nodes.*.name, yandex_compute_instance.kub-worker-nodes.*.network_interface.0.nat_ip_address))
    list_cp                     = join("\n", yandex_compute_instance.kub-cp-nodes.*.name)
    list_worker                 = join("\n", yandex_compute_instance.kub-worker-nodes.*.name)
  }  
  

  depends_on = [
    yandex_compute_instance.kub-cp-nodes,
    yandex_compute_instance.kub-worker-nodes,
  ]
}

resource "null_resource" "inventories" {
  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > ../kubespray/inventory/kub-cluster/host.ini"
  }

  triggers = {
    template = data.template_file.inventory.rendered
  }
}

resource "local_file" "inventory-git" {
  count   = 1
  content = <<-DOC

    [all]
    gitlab ansible_host=${yandex_compute_instance.gitlab[count.index].network_interface.0.nat_ip_address}

    DOC
  filename = "./ansible/inventory/hosts"

  depends_on = [
    yandex_compute_instance.gitlab
  ]
}

resource "local_file" "variables" {
  count   = 1
  content = <<-DOC
    ---
    ip: "${yandex_compute_instance.gitlab[count.index].network_interface.0.nat_ip_address}"

    DOC
  filename = "./ansible/group_vars/all/vars.yml"

  depends_on = [
    yandex_compute_instance.gitlab
  ]
}
