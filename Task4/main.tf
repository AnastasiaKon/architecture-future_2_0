terraform {
  required_version = ">= 1.5"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
}

provider "yandex" {
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zones[0]
  service_account_key_file = var.sa_key_file
}

locals {
  name_prefix = "${var.project}-${var.domain}-${var.environment}"
  common_labels = {
    project     = var.project
    domain      = var.domain
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Сеть: VPC, подсети в двух зонах, NAT-шлюз, таблица маршрутов
# ---------------------------------------------------------------------------

resource "yandex_vpc_network" "main" {
  name   = "${local.name_prefix}-net"
  labels = local.common_labels
}

resource "yandex_vpc_gateway" "nat" {
  name = "${local.name_prefix}-nat"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  name       = "${local.name_prefix}-rt-private"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

resource "yandex_vpc_subnet" "app" {
  count          = length(var.zones)
  name           = "${local.name_prefix}-app-${var.zones[count.index]}"
  zone           = var.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.app_subnet_cidrs[count.index]]
  route_table_id = yandex_vpc_route_table.private.id
  labels         = local.common_labels
}

resource "yandex_vpc_subnet" "data" {
  count          = length(var.zones)
  name           = "${local.name_prefix}-data-${var.zones[count.index]}"
  zone           = var.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.data_subnet_cidrs[count.index]]
  labels         = local.common_labels
}

# ---------------------------------------------------------------------------
# Группы безопасности
# ---------------------------------------------------------------------------

resource "yandex_vpc_security_group" "app" {
  name       = "${local.name_prefix}-sg-app"
  network_id = yandex_vpc_network.main.id
  labels     = local.common_labels

  ingress {
    description    = "HTTPS от балансировщика / шлюза"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = var.ingress_cidrs
  }

  ingress {
    description    = "SSH только из бастион-сети"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.admin_cidrs
  }

  ingress {
    description       = "Трафик внутри группы (K8s, сервисы домена)"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Исходящий трафик через NAT"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "data" {
  name       = "${local.name_prefix}-sg-data"
  network_id = yandex_vpc_network.main.id
  labels     = local.common_labels

  ingress {
    description       = "PostgreSQL только из группы приложений"
    protocol          = "TCP"
    port              = 6432
    security_group_id = yandex_vpc_security_group.app.id
  }

  egress {
    description    = "Ответы"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Вычислительные узлы домена (IaaS): ВМ с загрузочным и отдельным диском данных
# ---------------------------------------------------------------------------

data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

resource "yandex_compute_disk" "data" {
  count  = var.vm_count
  name   = "${local.name_prefix}-data-disk-${count.index}"
  zone   = var.zones[count.index % length(var.zones)]
  type   = var.vm_data_disk_type
  size   = var.vm_data_disk_size_gb
  labels = local.common_labels
}

resource "yandex_compute_instance" "app" {
  count       = var.vm_count
  name        = "${local.name_prefix}-app-${count.index}"
  hostname    = "${local.name_prefix}-app-${count.index}"
  platform_id = var.vm_platform
  zone        = var.zones[count.index % length(var.zones)]
  labels      = local.common_labels

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory_gb
    core_fraction = var.vm_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = var.vm_boot_disk_type
      size     = var.vm_boot_disk_size_gb
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.data[count.index].id
    device_name = "data"
    auto_delete = false
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app[count.index % length(var.zones)].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.app.id]
  }

  scheduling_policy {
    preemptible = var.vm_preemptible
  }

  metadata = {
    ssh-keys  = "ubuntu:${var.ssh_public_key}"
    user-data = <<-EOT
      #cloud-config
      package_update: true
      packages: [docker.io, chrony]
      runcmd:
        - mkfs.ext4 -F /dev/disk/by-id/virtio-data || true
        - mkdir -p /data
        - mount /dev/disk/by-id/virtio-data /data
        - echo '/dev/disk/by-id/virtio-data /data ext4 defaults 0 2' >> /etc/fstab
    EOT
  }
}

# ---------------------------------------------------------------------------
# Managed PostgreSQL - OLTP домена (HA при двух хостах в разных зонах)
# ---------------------------------------------------------------------------

resource "yandex_mdb_postgresql_cluster" "oltp" {
  name                = "${local.name_prefix}-pg"
  environment         = var.environment == "prod" ? "PRODUCTION" : "PRESTABLE"
  network_id          = yandex_vpc_network.main.id
  security_group_ids  = [yandex_vpc_security_group.data.id]
  deletion_protection = var.environment == "prod"
  labels              = local.common_labels

  config {
    version = var.pg_version
    resources {
      resource_preset_id = var.pg_preset
      disk_type_id       = var.pg_disk_type
      disk_size          = var.pg_disk_size_gb
    }
    backup_window_start {
      hours   = 2
      minutes = 0
    }
    access {
      data_lens = false
    }
  }

  dynamic "host" {
    for_each = slice(var.zones, 0, var.pg_hosts)
    content {
      zone      = host.value
      subnet_id = yandex_vpc_subnet.data[index(var.zones, host.value)].id
    }
  }
}

resource "yandex_mdb_postgresql_database" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.oltp.id
  name       = var.pg_database
  owner      = yandex_mdb_postgresql_user.app.name
}

resource "yandex_mdb_postgresql_user" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.oltp.id
  name       = var.pg_user
  password   = var.pg_password
}

# ---------------------------------------------------------------------------
# Object Storage - снимки, исследования, data products домена (SSE-KMS)
# Бакет создаётся по IAM-токену сервисного аккаунта Terraform (роль editor);
# права сервисов домена на бакет назначаются отдельно, вне Terraform.
# ---------------------------------------------------------------------------

resource "yandex_kms_symmetric_key" "bucket" {
  name              = "${local.name_prefix}-kms-bucket"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"
  labels            = local.common_labels
}

resource "yandex_storage_bucket" "data" {
  bucket    = "${local.name_prefix}-${var.folder_id}"
  folder_id = var.folder_id
  max_size  = var.bucket_max_size_bytes

  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
