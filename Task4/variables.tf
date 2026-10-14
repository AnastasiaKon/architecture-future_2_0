variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "Каталог (folder) домена - у каждого домена свой"
  type        = string
}

variable "sa_key_file" {
  description = "Путь к JSON-ключу сервисного аккаунта с ролью editor на каталог"
  type        = string
  default     = "sa-key.json"
}

variable "project" {
  description = "Имя проекта"
  type        = string
  default     = "future20"
}

variable "domain" {
  description = "Домен, для которого разворачивается окружение (clinic, fintech, ai, data, pharma ...)"
  type        = string
}

variable "environment" {
  description = "Окружение: dev, stage, prod"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment должен быть dev, stage или prod."
  }
}

variable "zones" {
  description = "Зоны доступности; минимум две для отказоустойчивости"
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-d", "ru-central1-e"]
}

variable "app_subnet_cidrs" {
  description = "CIDR подсетей приложений, по одной на зону"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDR подсетей данных (managed-БД), по одной на зону"
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
}

variable "ingress_cidrs" {
  description = "Откуда разрешён HTTPS к узлам приложений"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_cidrs" {
  description = "Откуда разрешён SSH (бастион / VPN)"
  type        = list(string)
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ администратора"
  type        = string
}

variable "vm_count" {
  description = "Число узлов приложений (распределяются по зонам)"
  type        = number
  default     = 2
}

variable "vm_platform" {
  description = "Платформа ВМ"
  type        = string
  default     = "standard-v3"
}

variable "vm_cores" {
  type    = number
  default = 4
}

variable "vm_memory_gb" {
  type    = number
  default = 8
}

variable "vm_core_fraction" {
  description = "Гарантированная доля vCPU, %"
  type        = number
  default     = 100
}

variable "vm_preemptible" {
  description = "Прерываемые ВМ (только для dev)"
  type        = bool
  default     = false
}

variable "vm_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "vm_boot_disk_type" {
  type    = string
  default = "network-ssd"
}

variable "vm_boot_disk_size_gb" {
  type    = number
  default = 30
}

variable "vm_data_disk_type" {
  type    = string
  default = "network-ssd"
}

variable "vm_data_disk_size_gb" {
  type    = number
  default = 100
}

variable "pg_version" {
  type    = string
  default = "16"
}

variable "pg_preset" {
  description = "Класс хостов Managed PostgreSQL"
  type        = string
  default     = "s3-c2-m8"
}

variable "pg_disk_type" {
  type    = string
  default = "network-ssd"
}

variable "pg_disk_size_gb" {
  type    = number
  default = 50
}

variable "pg_hosts" {
  description = "Число хостов PostgreSQL (2+ в разных зонах = HA)"
  type        = number
  default     = 2
}

variable "pg_database" {
  type    = string
  default = "app"
}

variable "pg_user" {
  type    = string
  default = "app"
}

variable "pg_password" {
  type      = string
  sensitive = true
}

variable "bucket_max_size_bytes" {
  description = "Лимит размера бакета, байт"
  type        = number
  default     = 1099511627776
}
