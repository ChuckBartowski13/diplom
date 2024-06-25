variable "yandex_cloud_id" {
  default = "*****"
}

variable "yandex_folder_id" {
  default = "*****"
}

###yandex_compute_image vars
variable "image" {
  type        = string
  default     = "fd8re3hiqnikqr7j7m8s"
}

variable "subnet-zones" {
  type    = list(string)
  default = ["ru-central1-a", "ru-central1-b", "ru-central1-c"]
}

variable "cidr" {
  type    = list(string)
  default = ["10.128.0.0/24", "10.129.0.0/24", "10.130.0.0/24"]    
}
