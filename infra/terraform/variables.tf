variable "zone_id" {
  type        = string
  description = "Existing appsdoc.com zone ID."
}

variable "hostname" {
  type    = string
  default = "social.appsdoc.com"
}

variable "origin_ipv4" {
  type        = string
  default     = ""
  description = "Current A-record target (the Frankfurt server). Set together with social_record_id."
}

variable "social_record_id" {
  type        = string
  default     = ""
  description = <<-EOT
    ID of the existing proxied A record for var.hostname. Empty = the record is
    not yet adopted by this state (the API token in use has no DNS read access).
    When set, Terraform imports the record and manages it unchanged
    (proxied, same target).
  EOT
}

variable "account_id" {
  type        = string
  description = "Existing Cloudflare account ID."
}

variable "google_identity_provider_id" {
  type        = string
  description = "UUID of the existing Google Workspace identity provider in Zero Trust (not a Google client/group ID)."
}

variable "access_team_domain" {
  type        = string
  default     = "appsdoc.cloudflareaccess.com"
  description = "Zero Trust team domain that issues the OIDC endpoints."
}

variable "team_group_email" {
  type    = string
  default = "team@appsdoc.com"
}

variable "launcher_name" {
  type    = string
  default = "Social Media"
}
