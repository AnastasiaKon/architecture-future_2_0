output "network_id" {
  description = "VPC домена"
  value       = yandex_vpc_network.main.id
}

output "app_subnet_ids" {
  description = "Подсети приложений по зонам"
  value       = yandex_vpc_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Подсети данных по зонам"
  value       = yandex_vpc_subnet.data[*].id
}

output "nat_gateway_id" {
  value = yandex_vpc_gateway.nat.id
}

output "app_vm_internal_ips" {
  description = "Внутренние адреса узлов приложений"
  value       = { for vm in yandex_compute_instance.app : vm.name => vm.network_interface[0].ip_address }
}

output "app_security_group_id" {
  value = yandex_vpc_security_group.app.id
}

output "postgresql_cluster_id" {
  value = yandex_mdb_postgresql_cluster.oltp.id
}

output "postgresql_fqdns" {
  description = "FQDN хостов PostgreSQL"
  value       = yandex_mdb_postgresql_cluster.oltp.host[*].fqdn
}

output "postgresql_connection" {
  description = "Строка подключения через встроенный балансировщик"
  value       = "postgresql://${var.pg_user}@c-${yandex_mdb_postgresql_cluster.oltp.id}.rw.mdb.yandexcloud.net:6432/${var.pg_database}"
}

output "bucket_name" {
  value = yandex_storage_bucket.data.bucket
}

output "kms_key_id" {
  value = yandex_kms_symmetric_key.bucket.id
}
