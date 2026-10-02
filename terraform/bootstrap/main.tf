
# 1. Создаем Сервисный Аккаунт для Terraform
resource "yandex_iam_service_account" "sa" {
  name        = "sa-diplom"
  description = "Сервисный аккаунт для управления инфраструктурой диплома"
}

# Назначаем роль editor на каталог
resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# 2. Создаем статический ключ доступа для работы с S3
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Статический ключ для S3 бакета"
}

# 3. Создаем KMS ключ для шифрования бакета (требование безопасности)
resource "yandex_kms_symmetric_key" "secret_key" {
  name              = "bucket-kms-key"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 1 год
}

# 4. Создаем S3 Бакет для хранения terraform.tfstate
resource "yandex_storage_bucket" "state_bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  bucket     = var.bucket_name

  anonymous_access_flags {
    read = false
    list = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.secret_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
