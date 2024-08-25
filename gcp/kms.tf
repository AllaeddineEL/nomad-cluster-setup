#Create a KMS key ring
resource "google_kms_key_ring" "key_ring" {
  project  = var.project
  name     = "vault-key-ring"
  location = "global"
}

#Create a crypto key for the key ring
resource "google_kms_crypto_key" "crypto_key" {
  name            = "vault-crypto-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "100000s"
}

# Add the service account to the Keyring
resource "google_kms_key_ring_iam_binding" "vault_iam_kms_binding" {
  key_ring_id = google_kms_key_ring.key_ring.id
  role        = "roles/owner"

  members = [
    "serviceAccount:${google_service_account.vault_kms_service_account.email}",
  ]
}
