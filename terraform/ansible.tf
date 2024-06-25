resource "null_resource" "wait" {
  provisioner "local-exec" {
    command = "sleep 200"
  }

  depends_on = [
    null_resource.inventories
  ]
}

resource "null_resource" "kubernetes" {
  provisioner "local-exec" {
    command = "ANSIBLE_FORCE_COLOR=1 ansible-playbook -u ubuntu -b -i ../kubespray/inventory/kub-cluster/host.ini ../kubespray/cluster.yml"
  }

  depends_on = [
    null_resource.wait
  ]
}

resource "null_resource" "wait-git" {
  provisioner "local-exec" {
    command = "sleep 150"
  }

  depends_on = [
    local_file.inventory-git,
    local_file.variables
  ]
}

resource "null_resource" "gitlab" {
  provisioner "local-exec" {
    command = "ANSIBLE_FORCE_COLOR=1 ansible-playbook -u ubuntu -b -i ./ansible/inventory/hosts ./ansible/gitlab.yml"
  }

  depends_on = [
    null_resource.wait-git
  ]
}
