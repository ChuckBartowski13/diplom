resource "yandex_compute_instance" "kub-cp-nodes" {  
  count   = 1
  name                      = "kub-cp-${count.index}"
  zone                      = "${var.subnet-zones[count.index]}"
  hostname                  = "kub-cp-${count.index}"
  allow_stopping_for_update = true
  labels = {
    index = "${count.index}"
  } 
 
  scheduling_policy {
  preemptible = true  // Прерываемая ВМ
  }

  resources {
    cores  = 2
    memory = 2
    core_fraction  = 20
  }

  boot_disk {
    initialize_params {
      image_id    = "${var.image}"
      type        = "network-ssd"
      size        = "20"
    }
  }

  network_interface {
    subnet_id  = "${yandex_vpc_subnet.subnet-zones[count.index].id}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
resource "yandex_compute_instance" "kub-worker-nodes" {  
  count   = 2
  name                      = "kub-worker-${count.index}"
  zone                      = "${var.subnet-zones[count.index]}"
  hostname                  = "kub-worker-${count.index}"
  allow_stopping_for_update = true
  labels = {
    index = "${count.index}"
  } 
 
  scheduling_policy {
  preemptible = true  // Прерываемая ВМ
  }

  resources {
    cores  = 2
    memory = 4
    core_fraction  = 20
  }

  boot_disk {
    initialize_params {
      image_id    = "${var.image}"
      type        = "network-ssd"
      size        = "20"
    }
  }

  network_interface {
    subnet_id  = "${yandex_vpc_subnet.subnet-zones[count.index].id}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
resource "yandex_compute_instance" "gitlab" {  
  count   = 1
  name                      = "gitlab"
  zone                      = "${var.subnet-zones[count.index]}"
  hostname                  = "gitlab"
  allow_stopping_for_update = true
  labels = {
    index = "${count.index}"
  } 
 
  scheduling_policy {
  preemptible = true  // Прерываемая ВМ
  }

  resources {
    cores  = 2
    memory = 4
    core_fraction  = 20
  }

  boot_disk {
    initialize_params {
      image_id    = "${var.image}"
      type        = "network-ssd"
      size        = "20"
    }
  }

  network_interface {
    subnet_id  = "${yandex_vpc_subnet.subnet-zones[count.index].id}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
