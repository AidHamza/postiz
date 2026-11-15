# Team login for Postiz: Cloudflare Access acts as the OIDC provider (backed by
# the existing Google Workspace IdP) for Postiz's generic OAuth login
# (POSTIZ_GENERIC_OAUTH). The same SaaS application is the hub.appsdoc.com
# launcher tile.
#
# Security note: Postiz v2.26.0 lets GENERIC (OIDC) users register even with
# DISABLE_REGISTRATION=true (AuthService.canRegister). This Access policy is
# therefore the gate: only members of team_group_email can obtain a token.
# The site itself is NOT behind Access (media and provider callbacks stay
# reachable); Postiz authentication protects every private route.

resource "cloudflare_zero_trust_access_policy" "postiz_team" {
  account_id = var.account_id
  name       = "AppsDoc Postiz team"
  decision   = "allow"
  include = [{
    gsuite = {
      email                = var.team_group_email
      identity_provider_id = var.google_identity_provider_id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "postiz" {
  account_id           = var.account_id
  name                 = var.launcher_name
  type                 = "saas"
  logo_url             = "https://${var.hostname}/logo.svg"
  allowed_idps         = [var.google_identity_provider_id]
  app_launcher_visible = true
  session_duration     = "12h"
  policies             = [{ id = cloudflare_zero_trust_access_policy.postiz_team.id, precedence = 1 }]
  saas_app = {
    auth_type        = "oidc"
    app_launcher_url = "https://${var.hostname}/auth/login"
    # Postiz v2.26.0 oauth.provider.ts: redirect_uri = ${FRONTEND_URL}/settings,
    # scope "openid profile email", client secret sent in the token POST body.
    redirect_uris = ["https://${var.hostname}/settings"]
    grant_types   = ["authorization_code"]
    scopes        = ["openid", "email", "profile"]
  }
}

locals {
  oidc_base = "https://${var.access_team_domain}/cdn-cgi/access/sso/oidc/${cloudflare_zero_trust_access_application.postiz.saas_app.client_id}"
}
