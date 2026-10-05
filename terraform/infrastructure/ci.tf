# =============================================================================
# CI/CD (stage 5): credentials for GitHub Actions in the diploma-app repository
# =============================================================================

# Service account that is allowed ONLY to push images to this registry
resource "yandex_iam_service_account" "ci" {
  name        = "sa-ci-registry"
  description = "CI: push Docker images to Container Registry"
}

resource "yandex_container_registry_iam_binding" "ci_pusher" {
  registry_id = yandex_container_registry.diploma_registry.id
  role        = "container-registry.images.pusher"
  members     = ["serviceAccount:${yandex_iam_service_account.ci.id}"]
}

resource "yandex_iam_service_account_key" "ci" {
  service_account_id = yandex_iam_service_account.ci.id
  description        = "Key for GitHub Actions (docker login with json_key)"
}

# Key in the JSON format expected by `docker login --username json_key`.
# Marked sensitive: it is not printed in logs, read it with `terraform output`.
output "ci_registry_key" {
  sensitive = true
  value = jsonencode({
    id                 = yandex_iam_service_account_key.ci.id
    service_account_id = yandex_iam_service_account.ci.id
    created_at         = yandex_iam_service_account_key.ci.created_at
    key_algorithm      = yandex_iam_service_account_key.ci.key_algorithm
    public_key         = yandex_iam_service_account_key.ci.public_key
    private_key        = yandex_iam_service_account_key.ci.private_key
  })
}
