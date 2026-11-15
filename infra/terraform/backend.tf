# Remote state in the existing private R2 bucket, under a Postiz-only key.
# Never use openpanel/terraform.tfstate. Bucket and account endpoint are passed
# at init time from the gitignored backend.hcl (see backend.hcl.example), so
# this public repository carries no account identifiers.
#   source scripts/r2-backend-env.sh
#   terraform -chdir=infra/terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    key                         = "postiz/terraform.tfstate"
    region                      = "auto"
    use_lockfile                = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
