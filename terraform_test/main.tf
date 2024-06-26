resource "yandex_compute_instance" "gitlab-ter" {  
  name                      = "gitlab-ter"
  zone                      = "ru-central1-a"
  hostname                  = "gitlab"
  allow_stopping_for_update = true
 
  scheduling_policy {
  preemptible = true  // Прерываемая ВМ
  }

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id    = "fd8re3hiqnikqr7j7m8s"
      type        = "network-ssd"
      size        = "20"
    }
  }

  network_interface {
    subnet_id  = "${yandex_vpc_subnet.default.id}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/tmp/id_rsa.pub")}"
  }
}


resource "yandex_vpc_network" "subnet-zones" {
  name = "my-net"
}

resource "yandex_vpc_subnet" "subnet-zones" {
  name = "subnet"
  count          = 1
  name           = "subnet-${var.subnet-zones[count.index]}"
  zone           = "${var.subnet-zones[count.index]}"
  network_id     = "${yandex_vpc_network.subnet-zones.id}"
  v4_cidr_blocks = [ "${var.cidr[count.index]}" ]
}

# Provider
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">=0.13"


  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "churilov-bucket"
    region = "ru-central1"
    key    = "terraform.tfstate"
    
    access_key = "***"
    secret_key = "***"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # необходимая опция при описании бэкенда для Terraform версии 1.6.1 и старше.
    skip_s3_checksum            = true # необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.

  }
}

provider "yandex" {
  service_account_key_file = "/tmp/sa-key.json"
  cloud_id  = "b1gp7g3sgar05j2ih4en"
  folder_id = "b1gp1d8nc2hoglc4llu8"
}
