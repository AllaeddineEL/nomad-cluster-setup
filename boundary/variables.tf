variable "boundary_user" {
  type    = string
  default = "admin"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "The GCP region"
}
