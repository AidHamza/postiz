output "social_record_managed" {
  value = local.adopt_record
}

# Settings for the server's app.env. Read with
#   terraform output -json postiz_oidc_env   (contains the client secret; pipe, never print)
output "postiz_oidc_env" {
  sensitive = true
  value = {
    POSTIZ_GENERIC_OAUTH                  = "true"
    NEXT_PUBLIC_POSTIZ_OAUTH_DISPLAY_NAME = "AppsDoc Google Workspace"
    NEXT_PUBLIC_POSTIZ_OAUTH_LOGO_URL     = "https://${var.hostname}/logo.svg"
    POSTIZ_OAUTH_URL                      = "https://${var.access_team_domain}"
    POSTIZ_OAUTH_AUTH_URL                 = "${local.oidc_base}/authorization"
    POSTIZ_OAUTH_TOKEN_URL                = "${local.oidc_base}/token"
    POSTIZ_OAUTH_USERINFO_URL             = "${local.oidc_base}/userinfo"
    POSTIZ_OAUTH_CLIENT_ID                = cloudflare_zero_trust_access_application.postiz.saas_app.client_id
    POSTIZ_OAUTH_CLIENT_SECRET            = cloudflare_zero_trust_access_application.postiz.saas_app.client_secret
  }
}
