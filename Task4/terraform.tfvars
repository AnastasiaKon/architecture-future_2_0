cloud_id    = "b1gedoupagc29ih9fcbs"
folder_id   = "b1gfavikgcgho0p8hah7"
sa_key_file = "sa-key.json"

project     = "future20"
domain      = "clinic"
environment = "dev"

zones             = ["ru-central1-d", "ru-central1-e"]
app_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
data_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
ingress_cidrs     = ["0.0.0.0/0"]
admin_cidrs       = ["10.0.0.0/8"]

ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoxND3gcF++P9DeDeitBZYKWYWRfuxXLlvJ8vYe838n admin@future20"

vm_count             = 2
vm_platform          = "standard-v3"
vm_cores             = 2
vm_memory_gb         = 2
vm_core_fraction     = 20
vm_preemptible       = false
vm_boot_disk_type    = "network-hdd"
vm_boot_disk_size_gb = 10
vm_data_disk_type    = "network-hdd"
vm_data_disk_size_gb = 10

pg_version      = "16"
pg_preset       = "s3-c2-m8"
pg_disk_type    = "network-ssd"
pg_disk_size_gb = 20
pg_hosts        = 1
pg_database     = "clinic"
pg_user         = "clinic"

bucket_max_size_bytes = 107374182400
