terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone = var.zone
}

variable "zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-d"
}

variable "vm_user" {
  description = "SSH user for Ubuntu VMs"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Public SSH key for cloud VMs"
  type        = string
  default     = "~/.ssh/devdp_yc.pub"
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_vpc_network" "devdp" {
  name        = "devdp-network"
  description = "Network for DevOps final project"

  labels = {
    project = "devdp"
  }
}

resource "yandex_vpc_subnet" "devdp" {
  name           = "devdp-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.devdp.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_security_group" "app" {
  name        = "devdp-app-sg"
  description = "Security group for application VM"
  network_id  = yandex_vpc_network.devdp.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Application entrypoint"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Node Exporter from project subnet"
    port           = 9100
    v4_cidr_blocks = ["10.10.0.0/24"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "monitoring" {
  name        = "devdp-monitoring-sg"
  description = "Security group for monitoring VM"
  network_id  = yandex_vpc_network.devdp.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Grafana"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Prometheus"
    port           = 9090
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Alertmanager"
    port           = 9093
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Node Exporter from project subnet"
    port           = 9100
    v4_cidr_blocks = ["10.10.0.0/24"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "app" {
  name                      = "devdp-app"
  hostname                  = "devdp-app"
  platform_id               = "standard-v3"
  zone                      = var.zone
  allow_stopping_for_update = true

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.devdp.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app.id]
  }

  metadata = {
    "ssh-keys" = "${var.vm_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  labels = {
    project = "devdp"
    role    = "app"
  }
}

resource "yandex_compute_instance" "monitoring" {
  name                      = "devdp-monitoring"
  hostname                  = "devdp-monitoring"
  platform_id               = "standard-v3"
  zone                      = var.zone
  allow_stopping_for_update = true

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.devdp.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.monitoring.id]
  }

  metadata = {
    "ssh-keys" = "${var.vm_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  labels = {
    project = "devdp"
    role    = "monitoring"
  }
}

output "app_public_ip" {
  description = "Public IPv4 of application VM"
  value       = yandex_compute_instance.app.network_interface[0].nat_ip_address
}

output "app_private_ip" {
  description = "Private IPv4 of application VM"
  value       = yandex_compute_instance.app.network_interface[0].ip_address
}

output "monitoring_public_ip" {
  description = "Public IPv4 of monitoring VM"
  value       = yandex_compute_instance.monitoring.network_interface[0].nat_ip_address
}

output "monitoring_private_ip" {
  description = "Private IPv4 of monitoring VM"
  value       = yandex_compute_instance.monitoring.network_interface[0].ip_address
}

output "ssh_app" {
  value = "ssh -i ~/.ssh/devdp_yc ${var.vm_user}@${yandex_compute_instance.app.network_interface[0].nat_ip_address}"
}

output "ssh_monitoring" {
  value = "ssh -i ~/.ssh/devdp_yc ${var.vm_user}@${yandex_compute_instance.monitoring.network_interface[0].nat_ip_address}"
}

output "frontend_url" {
  description = "Public application URL"
  value       = "http://${yandex_compute_instance.app.network_interface[0].nat_ip_address}"
}

output "backend_health_url" {
  description = "Backend health endpoint through Nginx"
  value       = "http://${yandex_compute_instance.app.network_interface[0].nat_ip_address}/health"
}

output "grafana_url" {
  value = "http://${yandex_compute_instance.monitoring.network_interface[0].nat_ip_address}:3000"
}

output "prometheus_url" {
  value = "http://${yandex_compute_instance.monitoring.network_interface[0].nat_ip_address}:9090"
}
